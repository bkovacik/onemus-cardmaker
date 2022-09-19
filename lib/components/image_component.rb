require_relative 'base_component'

class ImageComponent < BaseComponent
  def initialize(name, field, card, globals, aspects, images)
    super(name, field, card, globals, aspects)

    @globals = globals
    @aspects = aspects

    @imagepath = images
    @imagepath += card[name] if card[name]
  end

  def draw(dpi)
    temp = Image.read(@imagepath).first

    temp = tile_crop_resize(temp, dpi)

    if (@field['color'])
      background = Image.new(temp.columns, temp.rows) do |image|
        image.background_color = 'transparent'
      end
      temp_dr = create_new_drawing()

      temp_dr.rectangle(0, 0, temp.columns, temp.rows)
      temp_dr.draw(background)

      background.composite!(temp, Magick::CenterGravity, Magick::CopyAlphaCompositeOp)

      background.composite!(temp, Magick::CenterGravity, string_to_copyop(@field['combine']))
    else
      background = temp
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

      resize = false

      ['x', 'y'].each do |a|
        if (@field['size' + a])
          size[a] = @field['size' + a]*dpi
          resize = true
        end
      end

      if (@field['tile'])
        image = tile_image(image, dpi) if @field['tile']
      elsif (resize)
        scaleX = size['x']/image.columns
        scaleY = size['y']/image.rows

        scale = scaleX
        scale = scaleY if scaleY > scaleX

        image.resize!(image.columns*scale, image.rows*scale, Magick::LanczosFilter, 0.7)
      end

      image.crop!(Magick::CenterGravity, size['x'], size['y']) if (@field['crop'])

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

      montage = tiledImage.montage() do |image|
        image.geometry = "#{tilex}x#{tiley}+0+0"
        image.background_color = 'transparent'
        image.tile = "#{timesX}x#{timesY}"
      end
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
end
