require 'rmagick'
require 'yaml'
require_relative 'size_image'
include Magick

DEFAULT_TEXT_SIZE = 0.15
FONT_DIR = 'C:/Windows/Fonts/'

SizeStruct = Struct.new(:sizex, :sizey) do
end

class CardRenderer
  def initialize(args)
    confdir = File.expand_path('../config', File.dirname(__FILE__))
    @colors = YAML.load_file(confdir + args['colors'])
    @layout = YAML.load_file(confdir + args['cardlayout'])['layout']
    @cardList = YAML.load_file(confdir + args['cardlist'])
    @symbols = YAML.load_file(confdir + args['symbols'])['symbols']
    @statictext = YAML.load_file(confdir + args['statictext'])['texts']
    @images = args['images']
    @outdir = args['outdir']

    @imageCache = {}

    @dpi = args['dpi'] ? args['dpi'] : @layout['dpi']

    @aspects = @colors['aspects']

    @globals = @colors['globals']

    @fields = @layout['fields'] 

    @tile = args['tile']

    @cardX = (@layout['x'] * @dpi).floor
    @cardY = (@layout['y'] * @dpi).floor
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

    unless (card['name'].nil?)
      name = card['name'] + '.png'
    else
      raise "Card (#{card}) has no name field!"
    end

    outpath = File.expand_path(@outdir + name, File.dirname(__FILE__))
    c.write(outpath)
  end

  def render_cardlist(name)
    imageList = ImageList.new

    index = 0
    @cardList['cards'].each do |card|
      (1..card['copies']).each do |copy|
        if (@imageCache[card['name']].nil?)
          raise "No image for card #{card['name']} found!"
        end

        imageList << @imageCache[card['name']]
      end
    end

    tile = @tile

    imageList.montage{
      self.geometry = "#{@cardX}x#{@cardY}+2+2"
      self.tile = tile
    }.write(File.expand_path(@outdir + name, File.dirname(__FILE__)))
  end

  private
    # Draws a card to image
    # Mutates image
    def draw!(image, card) 
      drawHash = {};

      @fields.each do |name, field|
        d = Draw.new
        color = field['color']
        pos = {}

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
          when 'icon', 'image'
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
      imagepath = @images + field['image']
      temp = Image.read(imagepath).first

      imageinfo = Image.ping(imagepath).first
      size = {}
      size['x'] = imageinfo.columns
      size['y'] = imageinfo.rows

      # Resize if size values are present
      ['x', 'y'].each do |a|
        if (field['size' + a]) 
          size[a] = field['size' + a]*@dpi
        else
          field['size' + a] = size[a]/@dpi
        end
      end

      temp.resize!(size['x'], size['y'])

      pos = relative_to_value(drawHash, field, card)

      rotate_image!(field, temp)

      r = Math.sin(45*Math::PI/180)*size.values.min
      rad = field['rotate'] ? Math::PI*(field['rotate']+45)/180 : 0

      adjust_size!(size, field['rotate'])
      min_axis = size.values.min

      bbox = temp.bounding_box
      drawHash[name] = SizeStruct.new(bbox.width, bbox.height)

      image.composite!(
        temp,
        pos['x'] - min_axis/2 + r*Math.cos(rad),
        pos['y'] - min_axis/2 + r*Math.sin(rad),
        OverCompositeOp
      )
    end

    # Draws rectangle on image
    # Mutates image
    def draw_rect!(name, field, image, card, drawHash, shape)
      color = field['color']
      d = Draw.new
      d.fill = @globals[color].nil? ?
        @aspects[card['aspect']]['color'][color] : @globals[color]

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
      d = Draw.new

      n = n.to_i
      side = field['side']*@dpi
      m = get_poly_meas(side, n)
      dims = get_poly_dims(side, n)
      r = m[:r]

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

      d = Draw.new 
      font = FONT_DIR +
        (field['font'].nil? ? @layout['font'] : field['font']) +
        '.ttf'
      unless File.file?(font)
        raise "#{font} not found!"
      else
        d.font = font 
      end

      @symbols.each do |symbol|
        if (symbol['image'] and symbol['fields'].include?(name))
          temp = []

          text.each_with_index do |token, i|
            if (token.class == SizeImage)
              temp.push(token)
            elsif (!token.empty?)
              tokens = token.split(/(#{symbol['symbol']})/)
              temp.push(*tokens)
            end
          end

          imagepath = @images + symbol['replace']

          m = Image.ping(imagepath).first
          replace_image = SizeImage.new(
            Image.read(imagepath).first,
            { 'rows' => m.rows, 'columns' => m.columns }
          ) 
          text = temp.flatten.map { |x| 
            if (x == symbol['symbol']) 
              replace_image
            else
              x
            end
          }
        end
      end

      il = ImageList.new

      text.delete('')

      fontsize = field['textsize'].nil? ?
        DEFAULT_TEXT_SIZE*@dpi : field['textsize']*@dpi
      d.pointsize = fontsize

      height = d.get_type_metrics('.').height
      #min = tt.measurements['rows']
      textlength = 0

      text.each_with_index do |item, i|
        if (item.class == SizeImage)
          sc = height/item.measurements['rows']
          item.measurements['columns'] *= sc
          item.measurements['rows'] *= sc

          textlength += item.measurements['columns']*sc
        else
          textlength += d.get_type_metrics(item).width
        end
      end

      scale = field['sizey'] ?
        (field['sizex']*field['sizey']*@dpi**2)/height/textlength : 1
      scale = [scale, 1].min

      d.pointsize = fontsize*scale
      d.gravity = SouthWestGravity

      lines = break_text_with_image(field['sizex']*@dpi, text, d)

      lines.each_with_index do |line, i|
        tempimlist = ImageList.new

        line.each do |item|
          im = nil

          if (item.class == SizeImage)
            im = item.image.resize(
              scale*item.measurements['columns'],
              scale*item.measurements['rows']
            )
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

        tempimg = tempimlist.append(false)
        case field['align']
          when 'center'
            pad = ((field['sizex']*@dpi) - tempimg.bounding_box.width)/2
          when 'right'
            pad = ((field['sizex']*@dpi) - tempimg.bounding_box.width)
          else
            pad = 0
        end

        tempimlist.destroy!
        tempimlist = ImageList.new 

        unless (pad.zero?)
          padimg = Image.new(
            pad,
            tempimg.bounding_box.height
          ) {
            self.background_color = 'transparent'
          }
          tempimlist << padimg
        end

        tempimlist << tempimg

        il << tempimlist.append(false)
        tempimlist.destroy!
      end

      pos = relative_to_value(drawHash, field, card, 10)
      output = il.append(true)
      il.destroy!

      rotate_image!(field, output)

      bbox = output.bounding_box
      bbox_a = [bbox.width, bbox.height]
      drawHash[name] = SizeStruct.new(bbox.width, bbox.height)

      r = Math.sin(45*Math::PI/180)*bbox_a.min
      rad = field['rotate'] ? Math::PI*(field['rotate']+45)/180 : 0
      min_axis = bbox_a.min

      image.composite!(
        output,
        pos['x'] - min_axis/2 + r*Math.cos(rad),
        pos['y'] - min_axis/2 + r*Math.sin(rad),
        OverCompositeOp
      )
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
        image.background_color = 'none'
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
      tokens = textarray.flat_map{ |x| x.respond_to?(:split) ? x.split(' ') : x }

      result = []
      line = []
      linelength = 0

      tokens.each_with_index do |item, i|
        itemlength = item.class == SizeImage ?
          item.measurements['columns'] : draw.get_type_metrics(item + ' ').width

        if (itemlength + linelength > width)
          result << line
          line = [item]
          linelength = itemlength
        else
          if (!line.empty?)
            t = line.pop

            if (t.class != SizeImage)
              t += ' '
            end
            
            if (t.class == SizeImage or item.class == SizeImage)
              line << t << item

              line << ' ' if (i != tokens.length - 1)
            else
              line << t + item
            end
          else
            line << item
          end

          linelength += itemlength
        end
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
    # Returns {width, height}
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
end
