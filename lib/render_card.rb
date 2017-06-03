require 'rmagick'
require 'yaml'
include Magick

DEFAULT_TEXT_SIZE = 0.12
FONT_DIR = 'C:/Windows/Fonts/'

SizeStruct = Struct.new(:sizex, :sizey) do
end

class CardRenderer
  def initialize(args)
    confdir = File.expand_path('../config', File.dirname(__FILE__))
    @colors = YAML.load_file(confdir + args['colors'])

    cardlayout = YAML.load_file(confdir + args['cardlayout'])
    layout = cardlayout['layout']
    requires = cardlayout['requires']

    @dpi = args['dpi'] ? args['dpi'] : layout['dpi']

    @fields = layout['fields'] 
    @cardX = (layout['x'] * @dpi).floor
    @cardY = (layout['y'] * @dpi).floor
    @font = layout['font']

    if requires
      requires.each do |r|
        to_merge = YAML.load_file(confdir + r)['layout']['fields']
        @fields.merge!(to_merge) do |key,oldvalue,newvalue|
          oldvalue
        end
      end
    end

    @symbols = YAML.load_file(confdir + args['symbols'])['symbols']
    @statictext = YAML.load_file(confdir + args['statictext'])['texts']
    @images = args['images']

    @outdir = args['outdir']

    @aspects = @colors['aspects']

    @globals = @colors['globals']
  end

  # Takes in a hash representing a card and outputs an image to the outputs directory
  def render_card(card)
    c = Image.new(
      @cardX,
      @cardY
    ) {
      self.background_color = 'transparent'
      self.format = 'png'
    }

    draw!(c, card)

    if (card['name'])
      name = card['name'] + '.png'
    else
      raise "Card (#{card}) has no name field!"
    end

    outpath = File.expand_path(@outdir + name, File.dirname(__FILE__))
    c.write(outpath)
  end

  private
    # Draws a card to image
    # Mutates image
    def draw!(image, card) 
      drawHash = {};

      sorted_keys = @fields.keys.sort_by do |key|
        @fields[key]['z-index'] = 0 unless @fields[key]['z-index']
        @fields[key]['z-index']
      end

      sorted_keys.each do |name|
        field = @fields[name]

        # defaults
        unless (aspect = card['aspect']) then card['aspect'] = 'c' end
        unless field['rotate'] then field['rotate'] = 0 end

        case field['type']
          when 'text', 'static'
            draw_text!(name, field, image, card, drawHash)
          when 'rounded', 'rect'
            draw_rect!(name, field, image, card, drawHash)
          when /(\d+)gon/
            draw_poly!(name, field, image, card, drawHash, $1)
          when 'icon', 'image', 'aspect_icon'
            draw_image!(name, field, image, card, drawHash)
          else
            raise "Invalid type field for #{name}!"
        end
      end

      @imageCache[card['name']] = image
    end

    # Draws image on image
    # Mutates image
    def draw_image!(name, field, image, card, drawHash)
      case field['type']
        when 'icon'
          imagepath = @images + field['image']
        when 'image'
          imagepath = @images + card[name]
        when 'aspect_icon'
          imagepath = @images + field['images'][card['aspect']]
      end
          
      temp = Image.read(imagepath).first

      size = {
        'x' => temp.columns,
        'y' => temp.rows
      }

      # Resize if size values are present
      ['x', 'y'].each do |a|
        if (field['size' + a]) 
          size[a] = field['size' + a]*@dpi
        end
      end

      if (field['crop'])
        temp.resize_to_fill!(size['x'], size['y'], Magick::WestGravity)
      else
        temp.resize!(size['x'], size['y'])
      end

      if (field['color'])
        background = Image.new(temp.columns, temp.rows) {
          self.background_color = 'transparent'
        }
        temp_dr = create_new_drawing(field, card)

        temp_dr.rectangle(0, 0, temp.columns, temp.rows)
        temp_dr.draw(background)

        background.composite!(temp, Magick::CenterGravity, Magick::CopyOpacityCompositeOp)
        temp = background.composite!(temp, Magick::CenterGravity, string_to_copyop(field['combine']))
      end

      if (field['poly-mask'])
        mask = Image.new(size['x'], size['y']) {
          self.background_color = 'white'
        }

        draw_poly!(
          '',
          {
            'x' => 0,
            'y' => 0,
            'side' => field['side'] 
          },
          mask,
          {},
          {},
          field['poly-mask']
        )

        mask.alpha = Magick::DeactivateAlphaChannel
        mask = mask.negate

        temp_mask = temp.channel(Magick::OpacityChannel)
        temp_mask = temp_mask.negate

        mask.composite!(temp_mask, Magick::CenterGravity, Magick::MultiplyCompositeOp)
        
        temp.composite!(mask, Magick::CenterGravity, Magick::CopyOpacityCompositeOp)
      end


      position_image!(image, temp, drawHash, name, field, card)
    end

    # Draws rectangle on image
    # Mutates image
    def draw_rect!(name, field, image, card, drawHash)
      d = create_new_drawing(field, card)

      pos = relative_to_value(drawHash, field, card)
      rotate_drawing!(field, d, pos)

      case field['type']
        when 'rounded'
          d.roundrectangle(
            0,
            0,
            (field['sizex']*@dpi).floor - 1,
            (field['sizey']*@dpi).floor - 1,
            (field['cornerx']*@dpi).floor,
            (field['cornery']*@dpi).floor
          )
        when 'rect'
          d.rectangle(
            0,
            0,
            (field['sizex']*@dpi).floor,
            (field['sizey']*@dpi).floor,
          )
      end

      adjust_size!({'x' => field['sizex'], 'y' => field['sizey']}, field['rotate'])
      drawHash[name] = SizeStruct.new(field['sizex']*@dpi, field['sizey']*@dpi)
      d.draw(image)
    end

    # Draws n-gon on image
    # Mutates image
    def draw_poly!(name, field, image, card, drawHash, n)
      d = create_new_drawing(field, card)

      n = n.to_i
      side = field['side']*@dpi
      m = get_poly_meas(side, n)
      dims = get_poly_dims(side, n)
      r = m[:r]

      pos = relative_to_value(drawHash, field, card)
      rotate_drawing!(field, d, pos)

      angle_diff = 0
      if (field['round'])
        new_r = Math.sqrt(m[:apothem]**2 + (side/2-field['round']*@dpi)**2)
        angle_diff = Math.sin(m[:interior_angle]/2)*field['round']*@dpi/new_r
        iterations = [-1, 0, 1]
        labels = ['L', 'Q', '']
        radii = [new_r, r, new_r]
      else
        iterations = [0]
        labels = ['L']
        radii = [r]
      end

      if (n.odd?)
        rotate_offset = Math::PI/2-m[:center_angle]
      else
        if ((n/2).odd?)
          rotate_offset = 0
        else
          rotate_offset = m[:center_angle]/2
        end
      end

      coords = []
      n.times do |i|
        iterations.each_with_index do |a, j|
          str = labels[j]
          str += (radii[j] * Math.cos(m[:center_angle]*i - rotate_offset + angle_diff*a)\
            + dims[:offsetx]).to_i.to_s

          str += ','

          str += (radii[j] * Math.sin(m[:center_angle]*i - rotate_offset + angle_diff*a)\
            + dims[:offsety]).to_i.to_s

          coords << str 
        end
      end

      path = coords.join(' ')
      path[0] = ''
      path.prepend('M')
      path << ' Z'

      d.path(path)
      drawHash[name] = SizeStruct.new(dims[:width], dims[:height])
      d.draw(image) 
    end

    # Draws combined (text + image) on image
    # Mutates image
    def draw_text!(name, field, image, card, drawHash)
      case field['type']
        when 'text'
          text = [card[name]]
        when 'static' 
          return unless field['class'].split(',').include?(card['class'])
          text = [@statictext[field['text']]] 
      end

      return if text.first.nil?

      d = create_new_drawing(field, card)
      font = FONT_DIR +
        (field['font'].nil? ? @font : field['font']) +
        '.ttf'
      unless File.file?(font)
        raise "#{font} not found!"
      else
        d.font = font 
      end

      il = ImageList.new

      text = replace_with_symbols(text, name)
      text.delete('')

      fontsize = field['textsize'] ?
        field['textsize']*@dpi : DEFAULT_TEXT_SIZE*@dpi
      d.pointsize = fontsize

      height = d.get_type_metrics('.').height
      textlength = 0

      text.each_with_index do |item, i|
        if (item.class == Image)
          sc = height/item.rows
          item.resize!(sc)

          textlength += item.columns
        else
          textlength += d.get_type_metrics(item).width
        end
      end

      scale = field['sizey'] ?
        (field['sizex']*field['sizey']*@dpi**2)/height/textlength : 1
      scale = [scale, 1].min

      d.pointsize = fontsize*scale
      d.gravity = Magick::SouthWestGravity

      lines = break_text_with_image(field['sizex']*@dpi, text, d)

      lines.each_with_index do |line, i|
        tempimlist = ImageList.new

        populate_imglist!(line, tempimlist, d, scale)

        tempimg = tempimlist.append(false)

        case field['align']
          when 'center'
            pad = ((field['sizex']*@dpi) - tempimg.columns)/2
          when 'right'
            pad = ((field['sizex']*@dpi) - tempimg.columns)
          else
            pad = 0
        end
        pad = pad.to_i

        tempimlist.destroy!
        tempimlist = ImageList.new 

        unless (pad.zero?)
          padimg = Image.new(
            pad,
            tempimg.rows
          ) {
            self.background_color = 'transparent'
          }
          tempimlist << padimg
        end

        tempimlist << tempimg

        il << tempimlist.append(false)
        tempimlist.destroy!
      end

      output = il.append(true)
      il.destroy!

      position_image!(image, output, drawHash, name, field, card)
    end

    # Rotates drawing and translates coordinates back to "normal"
    # Mutates d
    def rotate_drawing!(field, d, pos)
      if (field['rotate'])
        d.rotate(field['rotate'])
        d.translate(
          *rotate_coords(
            pos['x'],
            pos['y'],
            -field['rotate']
          )
        )
      else
        d.translate(
          pos['x'],
          pos['y'],
        )
      end
    end

    # Rotates image
    # Mutates image
    def rotate_image!(field, image)
      if (field['rotate'])
        image.background_color = 'transparent'
        image.rotate!(field['rotate'])
      end
    end

    # Traverses relative fields and calculates the correct position
    # Returns the value calculated
    def relative_to_value(drawHash, field, card, padding=0)
      pos = {}
      {'x' => 'width', 'y' => 'height'}.each do |a, b|
        attribute = field[a]
        pos[a] = 0

        while (!attribute.is_a?(Numeric))
          o, f = attribute.split('.')
          attribute = @fields[o][f]

          sizey = drawHash[o][:sizey]
          pos[a] += sizey if sizey
          pos[a] += padding
        end

        pos[a] += (attribute*@dpi).floor
      end

      return pos
    end

    # Adjusts size to compensate for the resize from rotate_image
    # Mutates size[x] and size[y]
    def adjust_size!(size, rotate)
      unless (rotate) then return end

      if (rotate % 180 > 90)
        size['x'], size['y'] = size['y'], size['x']
      end

      rotate %= 90
      rotate *= Math::PI/180

      ['x', 'y'].each do |a|
        size[a] *= Math.sin(rotate) + Math.cos(rotate)
      end
    end

    # Breaks text based on the given width
    # Returns \n-broken text
    def break_text(width, text, draw)
      result = []
      line = ''
      t = text.split(' ')

      t.each_with_index do |word, i|
        if (draw.get_type_metrics(line + ' ' + word).width > width)
          result << line
          line = word
        else
          line += ' ' unless (i == 0)
          line += word
        end
      end

      unless (line.empty?)
        result << line
      end

      return result.join("\n")
    end

    # Breaks textarray based on the given width
    # Returns nested array
    def break_text_with_image(width, textarray, draw)
      tokens = textarray.flat_map{ |x| x.respond_to?(:split) ? x.split(/ /) : x }
      tokens = tokens.flat_map{ |x| x.respond_to?(:split) ? x.split(/(?<=\n)/) : x }

      result = []
      line = []
      linelength = 0

      tokens.each_with_index do |item, i|
        itemlength = item.class == Image ?
          item.columns : draw.get_type_metrics(item + ' ').width

        if (item.class != Image and item.include?("\n"))
          item.sub!("\n", '')
          line << item 
          result << line
          line = []
          linelength = 0
          next
        end

        if (line.empty?)
          line << item
        else
          if (itemlength + linelength > width)
            result << line
            line = [item]
            linelength = 0
          else
            t = line.pop

            t += ' ' if (t.class != Image)
            
            if (t.class == Image or item.class == Image)
              line << t << item

            else
              line << t + item
            end
          end
        end

        linelength += itemlength
      end

      unless (line.empty?)
        result << line
      end

      return result
    end

    def scale_down(text, size, d)
      if (size['sizey'].nil?)
        return 1
      end

      # scale down
      if (size['sizex'])
        m = d.get_type_metrics(text)
        scale = m.width*m.height/size['sizex']/@dpi
        y = size['sizey']*@dpi

        return [y/scale, 1].min
      end

      raise 'No sizey and/or sizex!'
    end

    # Rotates provided coords by deg
    # Returns [x', y']
    def rotate_coords(x, y, deg)
      d = deg * Math::PI / 180

      return [
        x*Math.cos(d) - y*Math.sin(d),
        x*Math.sin(d) + y*Math.cos(d)
      ]
    end

    # Reverse maps strings to RMagick constants
    # Returns the RMagick constant
    def to_constant(str)
      case str
      when 'left'
        return LeftAlign
      when 'right'
        return RightAlign
      when 'center'
        return CenterAlign
      end
    end

    # Takes in sidelength and number of sides
    # Returns {width, height, offsetx, offsety}
    def get_poly_dims(side, n)
      m = get_poly_meas(side, n)

      if (n.odd?)
        h = m[:apothem] + m[:r]
        w = Math.sin(m[:center_angle]*2)*m[:r]/Math.sin((Math::PI-m[:center_angle]*2)/2)
        offsety = m[:r]
      else
        if ((n/2).odd?)
          h = m[:apothem]*2
          w = m[:r]*2
        else
          h = m[:apothem]*2
          w = h
        end

        offsety = h/2
      end

      return {
        width: w,
        height: h,
        offsetx: w/2,
        offsety: offsety
      }
    end

    # Takes in sidelength and number of sides
    # Returns {interior_angle, center_angle, r, apothem}
    def get_poly_meas(side, n)
      interior_angle = (n-2)*Math::PI/n
      center_angle = 2*Math::PI/n

      r = side/Math.sin(center_angle)*Math.sin(interior_angle/2)
      apothem = r*Math.sin(interior_angle/2)

      return {
        interior_angle: interior_angle,
        center_angle: center_angle,

        r: r,
        apothem: apothem
      }
    end

    # Takes in array containing a string and the name of the field
    # Returns array of text and symbols 
    def replace_with_symbols(text, name)
      @symbols.each do |symbol|
        if (symbol['image'] and symbol['fields'].include?(name))
          temp = []

          text.each_with_index do |token, i|
            if (token.class == Image)
              temp.push(token)
            elsif (!token.empty?)
              tokens = token.split(/(#{symbol['symbol']})/)
              temp.push(*tokens)
            end
          end

          imagepath = @images + symbol['replace']

          m = Image.ping(imagepath).first
          replace_image = Image.read(imagepath).first

          text = temp.flatten.map { |x| 
            if (x == symbol['symbol']) 
              replace_image
            else
              x
            end
          }
        end
      end

      return text
    end

    # Takes in a line and an image list to populate with token images from the line
    # Mutates tempimlist
    def populate_imglist!(line, tempimlist, d, scale)
      line.each do |item|
        im = nil

        if (item.class == Image)
          im = item.resize(scale)
          im.background_color = 'transparent'
        else
          metrics = d.get_type_metrics(item)

          im = Image.new(
            metrics.width,
            metrics.height
          ) {
            self.background_color = 'transparent'
          }

          dr = d.clone
          dr.text(0, 0, item)
          dr.draw(im)
        end

        tempimlist << im
      end
    end

    # Positions to_position on other image and takes care of rotation etc.
    # Mutates image
    def position_image!(image, to_position, drawHash, name, field, card)
      if (field['lineheight'])
        pos = relative_to_value(drawHash, field, card, field['lineheight'])
      else
        pos = relative_to_value(drawHash, field, card)
      end

      rotate_image!(field, to_position)

      bbox_a = [to_position.columns, to_position.rows]
      drawHash[name] = SizeStruct.new(*bbox_a)

      r = Math.sin(45*Math::PI/180)*bbox_a.min
      rad = field['rotate'] ? Math::PI*(field['rotate']+45)/180 : 0
      min_axis = bbox_a.min

      image.composite!(
        to_position,
        pos['x'] - min_axis/2 + r*Math.cos(rad),
        pos['y'] - min_axis/2 + r*Math.sin(rad),
        OverCompositeOp
      )
    end

    # Creates a new drawing, taking care of boilerplate
    # Returns new drawing
    def create_new_drawing(field, card)
      d = Draw.new

      if (field['color'])
        color = field['color']

        d.fill = @globals[color] ?
          @globals[color] : @aspects[card['aspect']]['color'][color]
      end

      return d
    end

    # Returns a Magick version of a composite operator
    def string_to_copyop(str)
      case str
        when 'burn'
          return Magick::ColorBurnCompositeOp
        when 'dodge'
          return Magick::ColorDodgeCompositeOp
        when 'hardlight'
          return Magick::HardLightCompositeOp
        when 'overlay'
          return Magick::OverlayCompositeOp
        when 'softlight'
          return Magick::SoftLightCompositeOp
      end
    end
end
