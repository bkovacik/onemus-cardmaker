require_relative 'base_component'

class ImageComponent < BaseComponent
  def initialize(name, field, card, globals, aspects, images)
    super(name, field, card)

    @globals = globals
    @aspects = aspects

    @imagepath = images
    @imagepath += card[name] if card[name]
  end

  def draw(dpi)
    temp = Image.read(@imagepath).first

    temp = tile_crop_resize(temp, dpi)

    if (@field['color'])
      background = Image.new(temp.columns, temp.rows) {
        self.background_color = 'transparent'
      }
      temp_dr = create_new_drawing(@card)

      temp_dr.rectangle(0, 0, temp.columns, temp.rows)
      temp_dr.draw(background)

      background.composite!(temp, Magick::CenterGravity, Magick::CopyOpacityCompositeOp)

      background.composite!(temp, Magick::CenterGravity, string_to_copyop(@field['combine']))
    end

    return background
  end

  protected
    # Handles sizing options
    # Return image that has been tiled, cropped, or resized as needed
    def tile_crop_resize(image, dpi)
      size = {
        'x' => image.columns,
        'y' => image.rows
      }

      ['x', 'y'].each do |a|
        if (@field['size' + a])
          size[a] = @field['size' + a]*dpi
        end
      end

      if (@field['tile'] or @field['crop'])
        image = tile_image(image, dpi) if @field['tile']

        image.resize_to_fill!(size['x'], size['y'], Magick::WestGravity)
      else
        image.resize!(size['x'], size['y'])
      end

      return image
    end

    # Returns image tiled up to fieldsize
    def tile_image(image, dpi)
      tilex = @field['tilex']*dpi
      tiley = @field['tiley']*dpi

      tiledImage = ImageList.new

      temp = image.scale(tilex, tiley)

      timesX = (@field['sizex'].to_f/@field['tilex']).ceil
      timesY = (@field['sizey'].to_f/@field['tiley']).ceil

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

    def create_new_drawing(card)
      d = Draw.new

      if (@field['color'])
        color = @field['color']

        d.fill = @globals[color] ?
          @globals[color] : @aspects[card['aspect']]['color'][color]
      end

      return d
    end
end
