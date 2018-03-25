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
              card
            )
          when 'rounded'
            temp = RoundedComponent.new(
              name,
              field,
              card
            )
          when /(\d+)gon/
            temp = PolyComponent.new(
              name, 
              field,
              card,
              $1
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

        position_image!(image, temp.draw(@dpi), drawHash, name, field, card)
        temp = nil
      end

      @imageCache[card['name']] = image
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
    def position_image!(image, to_position, drawHash, name, field, card)
      pos = get_pos(field, drawHash)

      poly_mask!(to_position, field) if (field['poly-mask'])

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

    # Applies a poly-mask to an image
    def poly_mask!(image, field)
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
end
