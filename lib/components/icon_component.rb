require_relative 'image_component'

class IconComponent < ImageComponent
  def initialize(name, field, card, globals, aspects, images)
    super(name, field, card, globals, aspects, globals)

    @imagepath = images + field['image']
  end
end
