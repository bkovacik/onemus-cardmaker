include Magick

class BaseComponent
  def initialize(name, field, card)
    @name = name
    @field = field
    @card = card
  end

  def draw(dpi)
    return Image.new(2, 2) {
      self.background_color = 'transparent'
    }
  end

  protected
    # Creates a new drawing, taking care of boilerplate
    # Returns new drawing
    def create_new_drawing(field, card)
      return Draw.new
    end
end
