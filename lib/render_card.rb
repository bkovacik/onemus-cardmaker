require 'rmagick'
require 'yaml'

require_relative 'components/text_component'
require_relative 'components/static_component'
require_relative 'components/rectangle_component'
require_relative 'components/rounded_component'
require_relative 'components/poly_component'
require_relative 'components/image_component'
require_relative 'components/icon_component'
require_relative 'components/aspect_icon_component'

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
    @sortedKeys = get_sorted_keys_from_fields(@fields)
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
    @images = args['images'].chomp('/') + args['gamedir'] + '/'

    @outdir = args['outdir']

    @aspects = @colors['aspects']

    @globals = @colors['globals']

    @drawHash = {}
  end

  # Takes in a hash representing a card and outputs an image to the outputs directory
  def render_card(card)
    c = Image.new(@cardX, @cardY) do |image|
      image.background_color = 'transparent'
      image.format = 'png'
    end

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
      @sortedKeys.each do |name|
        field = @fields[name]

        # defaults
        unless field['rotate'] then field['rotate'] = 0 end

        temp = nil
        case field['type']
          when 'text'
            temp = TextComponent.new(
              name,
              field,
              card,
              @font,
              @globals,
              @aspects,
              @symbols,
              @images
            )
          when 'static'
            temp = StaticComponent.new(
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
          when 'rect'
            temp = RectangleComponent.new(
              name,
              field,
              card,
              @globals,
              @aspects
            )
          when 'rounded'
            temp = RoundedComponent.new(
              name,
              field,
              card,
              @globals,
              @aspects
            )
          when /(\d+)gon/
            temp = PolyComponent.new(
              name,
              field,
              card,
              $1,
              @globals,
              @aspects
            )
          when 'image'
            temp = ImageComponent.new(
              name,
              field,
              card,
              @globals,
              @aspects,
              @images
            )
          when 'icon'
            temp = IconComponent.new(
              name,
              field,
              card,
              @globals,
              @aspects,
              @images,
            )
          when 'aspect_icon'
            temp = AspectIconComponent.new(
              name,
              field,
              card,
              @globals,
              @aspects,
              @images
            )
          else
            raise "Invalid type field for #{name}!"
        end

        position_image!(image, temp.draw(@dpi), name, field, card)
        temp = nil
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

    # Positions to_position on other image and takes care of rotation etc.
    # Mutates image
    def position_image!(image, to_position, name, field, card)
      pos = get_pos(field)

      poly_mask!(field, to_position) if (field['poly-mask'])

      rotate_image!(field, to_position)

      to_position = drop_shadow(field, to_position) if (field['dropshadow'])

      bbox_a = [to_position.columns, to_position.rows]
      rows = field['sizey'] ? field['sizey'] : to_position.rows.to_f/@dpi
      @drawHash[name] = SizeStruct.new(
        resolve_field(field['x']),
        resolve_field(field['y']),
        to_position.columns.to_f/@dpi,
        rows,
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

    # Resolves a field using the @drawHash if necessary
    # Returns the resolved value
    def resolve_field(field)
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
          elsif (@drawHash.has_key?(matches[0]))
            @drawHash[matches[0]][matches[1].to_sym]
          else
            Float(token) rescue token
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
    def get_pos(field)
      pos = {}
      ['x', 'y'].each do |a|
        pos[a] = resolve_field(field[a])*@dpi
      end

      return pos
    end

    # Adds a drop shadow to an image
    def drop_shadow(field, image)
      shadow = image.copy().colorize(1, 1, 1, 'black')
      transposeX = field['dropshadow']['x'] ? field['dropshadow']['x'] : 0
      transposeY = field['dropshadow']['y'] ? field['dropshadow']['y'] : 0
      blur = field['dropshadow']['blur'] ? field['dropshadow']['blur'] : 0

      canvas = Image.new(
        image.columns + (transposeX.abs + blur*2)*@dpi,
        image.rows + (transposeY.abs + blur*2)*@dpi,
      ) do |image|
        image.background_color = 'transparent'
      end

      # Blur if transpose > blur, tranpose otherwise
      imageTransposeX = [[blur - transposeX, transposeX].max, blur].min

      shadowTransposeX = transposeX.abs - imageTransposeX + blur
      imageTransposeX = blur - imageTransposeX

      imageTransposeY = [[blur - transposeY, transposeY].max, blur].min

      shadowTransposeY = transposeY.abs - imageTransposeY + blur
      imageTransposeY = blur - imageTransposeY

      imageTransposeX, shadowTransposeX = shadowTransposeX + blur, imageTransposeX + blur if (transposeX < 0)
      imageTransposeY, shadowTransposeY = shadowTransposeY + blur, imageTransposeY + blur if (transposeY < 0)

      canvas.composite!(shadow, shadowTransposeX*@dpi, shadowTransposeY*@dpi, Magick::OverCompositeOp)
      canvas = canvas.gaussian_blur(blur*@dpi, blur/2*@dpi)

      canvas.composite!(image, imageTransposeX*@dpi, imageTransposeY*@dpi, Magick::OverCompositeOp)

      return canvas
    end

    # Applies a poly-mask to an image
    def poly_mask!(field, image)
      mask = Image.new(image.columns, image.rows) {
        self.background_color = 'white'
      }

      n = field['poly-mask']
      poly = PolyComponent.new(
        '',
        {
          'x' => 0,
          'y' => 0,
          'side' => field['side']
        },
        {},
        n
      )

      mask.composite!(poly.draw(@dpi), Magick::WestGravity, Magick::OverCompositeOp)
      mask.alpha = Magick::DeactivateAlphaChannel
      mask = mask.negate

      temp_mask = image.channel(Magick::OpacityChannel)
      temp_mask = temp_mask.negate

      mask.composite!(temp_mask, Magick::CenterGravity, Magick::MultiplyCompositeOp)

      return image.composite!(mask, Magick::CenterGravity, Magick::CopyOpacityCompositeOp)
    end

    # Returns keys bucket sorted by z-index
    def get_sorted_keys_from_fields(fields)
      buckets = {}
      fields.each do |key, value|
        zIndex = value['z-index'] ? value['z-index'] : 0
        if (!buckets.key?(zIndex))
          buckets[zIndex] = []
        end

        buckets[zIndex].append(key)
      end

      sortedKeys = []
      zIndices = buckets.keys.sort_by do |index|
        index
      end

      zIndices.each do |index|
        sortedKeys += buckets[index]
      end

      sortedKeys
    end
end
