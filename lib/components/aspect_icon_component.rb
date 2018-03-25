require_relative 'image_component'

class AspectIconComponent < ImageComponent
  def initialize(name, field, card, globals, aspects, images)
    super(name, field, card, globals, aspects, images)

    @imagepath = images + field['images'][card['aspect']]
  end
end
