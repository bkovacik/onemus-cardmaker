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

      if (@field['color'])
        color = @field['color']

        d.fill = @globals[color] ?
          @globals[color] : @aspects[@card['aspect']]['color'][color]
      end

      return d
    end
end
