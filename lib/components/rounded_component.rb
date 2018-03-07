require_relative 'rectangle_component'

class RoundedComponent < RectangleComponent
  protected
    def draw_rectangle(dpi, drawing)
      drawing.roundrectangle(
        0,
        0,
        (@field['sizex']*dpi).floor - 1,
        (@field['sizey']*dpi).floor - 1,
        (@field['round']*dpi).floor,
        (@field['round']*dpi).floor
      )
    end
end
