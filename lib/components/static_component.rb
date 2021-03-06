require_relative 'text_component'

class StaticComponent < TextComponent
  def initialize(
    name,
    field,
    card,
    font,
    globals,
    aspects,
    symbols,
    images,
    statictext
  )
    super(name, field, card, font, globals, aspects, symbols, images)

    @text = [statictext[field['text']]]
  end
end
