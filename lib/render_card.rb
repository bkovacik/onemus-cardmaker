require 'rmagick'
require 'yaml'

require_relative 'components/text_component'
require_relative 'components/static_component'

include Magick


SizeStruct = Struct.new(:x, :y, :sizex, :sizey) { |s| }

class CardRenderer
  def initialize(args)
    confdir = File.expand_path('../config' + args['gamedir'], File.dirname(__FILE__))
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

      sortedKeys = @fields.keys.sort_by do |key|
        @fields[key]['z-index'] = 0 unless @fields[key]['z-index']
        @fields[key]['z-index']
      end

      sortedKeys.each do |name|
        field = @fields[name]

        # defaults
        unless field['rotate'] then field['rotate'] = 0 end

        case field['type']
          when 'text'
            text = TextComponent.new(
              name,
              field,
              card,
              @font,
              @globals,
              @aspects,
              @symbols,
              @images
            )
            position_image!(image, text.draw(@dpi), drawHash, name, field, card)
            text = nil
          when 'static'
            text = StaticComponent.new(
              name,
              field,
              card,
              @font,
              @globals,
              @aspects,
              @symbols,
              @images,
              @statictext
            )
            position_image!(image, text.draw(@dpi), drawHash, name, field, card)
            text = nil
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

      temp = tile_crop_resize(temp, field)

      if (field['crop'])
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
        mask = Image.new(temp.columns, temp.rows) {
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

      pos = get_pos(field, drawHash)

      rotate_drawing!(field, d, pos)

      case field['type']
        when 'rounded'
          d.roundrectangle(
            0,
            0,
            (field['sizex']*@dpi).floor - 1,
            (field['sizey']*@dpi).floor - 1,
            (field['round']*@dpi).floor,
            (field['round']*@dpi).floor
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
      drawHash[name] = SizeStruct.new(
        resolve_field(field['x'], drawHash),
        resolve_field(field['y'], drawHash),
        resolve_field(field['sizex'], drawHash),
        resolve_field(field['sizey'], drawHash)
      )
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

      pos = get_pos(field, drawHash) 
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
      drawHash[name] = SizeStruct.new(
        dims[:offsetx],
        dims[:offsety],
        dims[:width],
        dims[:height]
      )
      d.draw(image) 
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

    # Positions to_position on other image and takes care of rotation etc.
    # Mutates image
    def position_image!(image, to_position, drawHash, name, field, card)
      pos = get_pos(field, drawHash)

      rotate_image!(field, to_position)

      bbox_a = [to_position.columns, to_position.rows]
      drawHash[name] = SizeStruct.new(
        resolve_field(field['x'], drawHash),
        resolve_field(field['y'], drawHash),
        to_position.columns.to_f/@dpi,
        to_position.rows.to_f/@dpi,
      )

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

    # Resolves a field using the drawHash if necessary
    # Returns the resolved value
    def resolve_field(field, drawHash)
      if (field.is_a?(Numeric))
        return field
      else
        operatorMatch = /([*+\/\-])/
        resolvedTokens = field.split(operatorMatch).map do |token|
          if (token =~ operatorMatch)
            next token
          end

          matches = /(\w+)\.(\w+)/.match(token).captures

          if (!matches.length)
            raise "Malformed token #{token}"
          elsif (drawHash.has_key?(matches[0]))
            drawHash[matches[0]][matches[1].to_sym]
          else
            matches[0]
          end
        end

        additionTokens = []
        tempTokens = []
        resolvedTokens.each do |token|
          if (token =~ /[+\-]/)
            additionTokens << do_operation(tempTokens)
            tempTokens = []

            additionTokens << token
          else
            tempTokens << token
          end
        end

        additionTokens += tempTokens

        return do_operation(additionTokens)
      end
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

    # Takes array in the form [operand, operator, operand,...]
    # Does NOT follow order of operations
    # Returns result
    def do_operation(opArray)
      if (!opArray.length)
        return 0
      end

      result = opArray.shift

      opArray.each_slice(2) do |a, b|
        result = result.send(a, b)
      end

      return result
    end

    # Returns only x, y values from field, converted from
    # fieldname
    def get_pos(field, drawHash)
      pos = {}
      ['x', 'y'].each do |a|
        pos[a] = resolve_field(field[a], drawHash)*@dpi
      end

      return pos
    end

    # Returns image tiled up to fieldsize
    def tile_image(image, field)
      tilex = field['tilex']*@dpi
      tiley = field['tiley']*@dpi

      tiledImage = ImageList.new

      temp = image.scale(tilex, tiley)

      timesX = (field['sizex'].to_f/field['tilex']).ceil
      timesY = (field['sizey'].to_f/field['tiley']).ceil

      (1..timesX).each do |x|
        (1..timesY).each do |y|
          tiledImage << temp
        end
      end

      montage = tiledImage.montage() {
        self.geometry = "#{tilex}x#{tiley}+0+0"
        self.background_color = 'transparent'
      }
      tiledImage.clear()

      return montage
    end

    # Handles sizing options
    # Return image that has been tiled, cropped, or resized as needed
    def tile_crop_resize(image, field)
      size = {
        'x' => image.columns,
        'y' => image.rows
      }

      ['x', 'y'].each do |a|
        if (field['size' + a])
          size[a] = field['size' + a]*@dpi
        end
      end

      if (field['tile'] or field['crop'])
        image = tile_image(image, field) if field['tile']

        image.resize_to_fill!(size['x'], size['y'], Magick::WestGravity)
      else
        image.resize!(size['x'], size['y'])
      end

      return image
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
end
