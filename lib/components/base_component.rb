require 'rmagick'

include Magick

class BaseComponent
  def initialize(name, field, card, globals, aspects)
    @name = name
    @field = field
    @card = card
    @globals = globals
    @aspects = aspects
  end

  def draw(dpi)
    return Image.new(1, 1) {
      self.background_color = 'transparent'
    }
  end

  protected
    # Creates a new drawing, taking care of boilerplate
    # Returns new drawing
    def create_new_drawing()
      d = Draw.new

      d.fill(get_color(@field['color'])) if (@field['color'])

      return d
    end

    # Gets the correct fill color for the drawing
    def get_color(color)
        return @globals[color] ?
          @globals[color] : @aspects[@card['aspect']]['color'][color]
    end
end
