require_relative 'base_component'

class RectangleComponent < BaseComponent
  def draw(dpi)
    d = create_new_drawing(@field, @card)
    image = Image.new(
      (@field['sizex']*dpi).floor,
      (@field['sizey']*dpi).floor
    )

    draw_rectangle(dpi, d)

    d.draw(image)
    return image
  end

  protected
    # Mutates drawing
    # Draws a rectangle on the drawing
    def draw_rectangle(dpi, drawing)
      drawing.roundrectangle(
        0,
        0,
        (@field['sizex']*dpi).floor,
        (@field['sizey']*dpi).floor
      )
    end
end
