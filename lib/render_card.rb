require 'rmagick'
require 'yaml'

require_relative 'components/text_component'
require_relative 'components/static_component'
require_relative 'components/rectangle_component'
require_relative 'components/rounded_component'
require_relative 'components/poly_component'

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
          when 'rect'
            rect = RectangleComponent.new(
              name,
              field,
              card
            )
            position_image!(image, rect.draw(@dpi), drawHash, name, field, card)
          when 'rounded'
            rect = RoundedComponent.new(
              name,
              field,
              card
            )
            position_image!(image, rect.draw(@dpi), drawHash, name, field, card)
          when /(\d+)gon/
            rect = PolyComponent.new(
              name, 
              field,
              card,
              $1
            )
            position_image!(image, rect.draw(@dpi), drawHash, name, field, card)
            #draw_poly!(name, field, image, card, drawHash, $1)
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

=begin
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
=end

        mask.alpha = Magick::DeactivateAlphaChannel
        mask = mask.negate

        temp_mask = temp.channel(Magick::OpacityChannel)
        temp_mask = temp_mask.negate

        mask.composite!(temp_mask, Magick::CenterGravity, Magick::MultiplyCompositeOp)
        
        temp.composite!(mask, Magick::CenterGravity, Magick::CopyOpacityCompositeOp)
      end

      position_image!(image, temp, drawHash, name, field, card)
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
