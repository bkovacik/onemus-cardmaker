require_relative 'base_component'

class PolyComponent < BaseComponent
  def initialize(name, field, card, n, globals, aspects)
    super(name, field, card, globals, aspects)

    @n = n.to_i
  end

  def draw(dpi)
    d = create_new_drawing()

    raise 'Polygon needs n of 3 or larger!' if [nil, 0, 1, 2].include?(@n)

    side = @field['side']*dpi
    m = get_poly_meas(side, @n)
    dims = get_poly_dims(side, @n)
    r = m[:r]

    # Create base nodes
    angle_diff = 0
    if (@field['round'])
      new_r = Math.sqrt(m[:apothem]**2 + (side/2-@field['round']*dpi)**2)
      angle_diff = Math.sin(m[:interior_angle]/2)*@field['round']*dpi/new_r
      iterations = [-1, 0, 1]
      labels = ['L', 'Q', '']
      radii = [new_r, r, new_r]
    else
      iterations = [0]
      labels = ['L']
      radii = [r]
    end

    # Rotate to a reasonable orientation
    if (@n.odd?)
      rotate_offset = Math::PI/2-m[:center_angle]
    else
      if ((@n/2).odd?)
        rotate_offset = 0
      else
        rotate_offset = m[:center_angle]/2
      end
    end

    # Compile the pathstring
    coords = []
    @n.times do |i|
      iterations.each_with_index do |a, j|
        str = labels[j]
        str += (radii[j] * Math.cos(m[:center_angle]*i - rotate_offset + angle_diff*a)\
          + dims[:offsetx]).to_i.to_s

        str += ','

        str += (radii[j] * Math.sin(m[:center_angle]*i - rotate_offset + angle_diff*a)\
          + dims[:offsety]).to_i.to_s

        coords << str
      end
    end

    path = coords.join(' ')
    path[0] = ''
    path.prepend('M')
    path << ' Z'

    d.path(path)
    image = Image.new(dims[:width], dims[:height]) {
      self.background_color = 'transparent'
    }
    d.draw(image)

    return image
  end

  protected
    # Takes in sidelength and number of sides
    # Returns {width, height, offsetx, offsety}
    def get_poly_dims(side, n)
      m = get_poly_meas(side, n)

      if (n.odd?)
        h = m[:apothem] + m[:r]
        widestvertex = (n+1)/4
        rotate_offset = Math::PI/2
        w = 2*m[:r]*Math.cos(m[:center_angle]*widestvertex-rotate_offset)
        offsety = m[:r]
      else
        if ((n/2).odd?)
          h = m[:apothem]*2
          w = m[:r]*2
        else
          h = m[:apothem]*2
          w = h
        end

        offsety = h/2
      end

      return {
        width: w,
        height: h,
        offsetx: w/2,
        offsety: offsety
      }
    end

    # Takes in sidelength and number of sides
    # Returns {interior_angle, center_angle, r, apothem}
    def get_poly_meas(side, n)
      interior_angle = (n-2)*Math::PI/n
      center_angle = 2*Math::PI/n

      r = side/Math.sin(center_angle)*Math.sin(interior_angle/2)
      apothem = r*Math.sin(interior_angle/2)

      return {
        interior_angle: interior_angle,
        center_angle: center_angle,

        r: r,
        apothem: apothem
      }
    end
end
