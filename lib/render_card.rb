require 'rmagick'
require 'yaml'
require_relative 'size_image'
include Magick

DEFAULT_TEXT_SIZE = 0.15
FONT_DIR = 'C:/Windows/Fonts/'

class CardRenderer
  def initialize(args)
    confdir = File.expand_path('../config', File.dirname(__FILE__))
    @colors = YAML.load_file(confdir + args['colors'])
    @layout = YAML.load_file(confdir + args['cardlayout'])['layout']
    @cardList = YAML.load_file(confdir + args['cardlist'])
    @symbols = YAML.load_file(confdir + args['symbols'])['symbols']
    @images = args['images']
    @outdir = args['outdir']

    @imageCache = {}

    @dpi = args['dpi'] ? args['dpi'] : @layout['dpi']

    @aspects = @colors['aspects']

    @globals = @colors['globals']

    @fields = @layout['fields'] 

    @tile = args['tile']

    @cardX = (@layout['x'] * @dpi).floor
    @cardY = (@layout['y'] * @dpi).floor
  end

  # Takes in a hash representing a card and outputs an image to the outputs directory
  def render_card(card)
    c = Image.new(
      @cardX,
      @cardY
    ) {
      self.background_color = 'transparent'
      self.format = 'png'
    }

    draw!(c, card)

    unless (card['name'].nil?)
      name = card['name'] + '.png'
    else
      raise "Card (#{card}) has no name field!"
    end

    outpath = File.expand_path(@outdir + name, File.dirname(__FILE__))
    c.write(outpath)
  end

  def render_cardlist(name)
    imageList = ImageList.new

    index = 0
    @cardList['cards'].each do |card|
      (1..card['copies']).each do |copy|
        if (@imageCache[card['name']].nil?)
          raise "No image for card #{card['name']} found!"
        end

        imageList << @imageCache[card['name']]
      end
    end

    tile = @tile

    imageList.montage{
      self.geometry = "#{@cardX}x#{@cardY}+2+2"
      self.tile = tile
    }.write(File.expand_path(@outdir + name, File.dirname(__FILE__)))
  end

  private
    # Draws a card to image
    # Mutates image
    def draw!(image, card) 
      drawHash = {};

      @fields.each do |name, field|
        d = Draw.new
        color = field['color']
        pos = {}

        # defaults
        unless (aspect = card['aspect']) then card['aspect'] = 'c' end
        unless field['rotate'] then field['rotate'] = 0 end

        case field['type']
        when 'combined'
          draw_combined!(name, field, image, card, drawHash)
        when 'rounded', 'rect'
          draw_shape!(name, field, image, card, drawHash, field['type'])
        when 'text'
          draw_text!(name, field, image, card, drawHash)
        when 'icon', 'image'
          draw_image!(name, field, image, card, drawHash)
        else
          raise "Invalid type field for #{name}!"
        end
      end

      @imageCache[card['name']] = image
    end

    # Draws image on image
    # Mutates image
    def draw_image!(name, field, image, card, drawHash)
      imagepath = @images + field['image']
      temp = Image.read(imagepath).first

      imageinfo = Image.ping(imagepath).first
      size = {}
      size['x'] = imageinfo.columns
      size['y'] = imageinfo.rows

      # Resize if size values are present
      ['x', 'y'].each do |a|
        if (field['size' + a]) 
          size[a] = field['size' + a]*@dpi
        else
          field['size' + a] = size[a]/@dpi
        end
      end

      temp.resize!(size['x'], size['y'])

      pos = relative_to_value(drawHash, field, card)

      # Draw rect to image as placeholder
      draw_shape!(name, field, image, card, drawHash, 'rect')      

      rotate_image!(field, temp)

      r = Math.sin(45*Math::PI/180)*size.values.min
      rad = field['rotate'] ? Math::PI*(field['rotate']+45)/180 : 0

      adjust_size!(size, field['rotate'])
      min_axis = size.values.min

      image.composite!(
        temp,
        pos['x'] - min_axis/2 + r*Math.cos(rad),
        pos['y'] - min_axis/2 + r*Math.sin(rad),
        OverCompositeOp
      )
    end

    # Creates image from text
    # Returns image
    def draw_text(name, field, image, card, drawHash)
      color = field['color']
      d = Draw.new
      drawHash[name] = d
      spacing = -5
      d.interline_spacing = spacing

      d.fill = @globals[color].nil? ?
        @aspects[card['aspect']]['color'][color] : @globals[color]

      fontsize = field['textsize'].nil? ?
        DEFAULT_TEXT_SIZE*@dpi : field['textsize']*@dpi
      d.pointsize = fontsize

      font = FONT_DIR +
        (field['font'].nil? ? @layout['font'] : field['font']) +
        '.ttf'
      unless File.file?(font)
        raise "#{font} not found!"
      else
        d.font = font 
      end
      unless field['align'].nil? then d.align = to_constant(field['align']) end

      pos = relative_to_value(drawHash, field, card)

      rotate_drawing!(field, d, pos)

      # compensate for text-align
      case field['align']
      when 'center'
        d.translate((field['sizex']*@dpi/2), 0)
      when 'right'
        d.translate((field['sizex']*@dpi).floor, 0)
      end

      size = {}
      if (card[name])
        if (field['scale'])
          fontsize *= (1 + field['scale'])/2
        else
          fontsize *= (1 + scale_down(card[name], field, d))/2
        end

        d.pointsize = fontsize

        broken_text = break_text(
          (field['sizex']*@dpi),
          card[name],
          d
        )

        d.text(
          0,
          0,
          broken_text
        )

        m = d.get_type_metrics(card[name])
        size = { 'x' => m.width, 'y' => m.height+spacing }
      end

      if (image.nil?)
        image = SizeImage.new(Image.new(
          size['x'],
          size['y']
        ) {
          self.background_color = 'transparent'
          self.format = 'png'
        }, { 'rows' => size['y'], 'columns' => size['x'] })
        d.gravity = SouthEastGravity
      end

      return [d, image]
    end

    # Draws text on image
    # Mutates image
    def draw_text!(name, field, image, card, drawHash)
      d, im, y = draw_text(name, field, image, card, drawHash)

      d.draw(image)
    end

    # Draws shape on image
    # Mutates image
    def draw_shape!(name, field, image, card, drawHash, shape)
      color = field['color']
      d = Draw.new
      drawHash[name] = d
      d.fill = @globals[color].nil? ?
        @aspects[card['aspect']]['color'][color] : @globals[color]

      pos = relative_to_value(drawHash, field, card)

      rotate_drawing!(field, d, pos)

      case shape
        when 'rounded'
          d.roundrectangle(
            0,
            0,
            (field['sizex']*@dpi).floor - 1,
            (field['sizey']*@dpi).floor - 1,
            (field['cornerx']*@dpi).floor,
            (field['cornery']*@dpi).floor
          )
        when 'rect'
          d.rectangle(
            0,
            0,
            (field['sizex']*@dpi).floor,
            (field['sizey']*@dpi).floor,
          )
      end

      d.draw(image)
    end

    # Draws combined (text + image) on image
    # Mutates image
    def draw_combined!(name, field, image, card, drawHash)
      if (card[name])
        text = [card[name]]

        @symbols.each do |symbol|
          if (symbol['image'] and symbol['fields'].include?(name))
            temp = []

            text.each_with_index do |token, i|
              if (token.class == SizeImage)
                temp.push(token)
              elsif (!token.empty?)
                tokens = token.split(/(#{symbol['symbol']})/)
                temp.push(*tokens)
              end
            end

            imagepath = @images + symbol['replace']

            m = Image.ping(imagepath).first
            replace_image = SizeImage.new(
              Image.read(imagepath).first,
              { 'rows' => m.rows, 'columns' => m.columns }
            ) 
            text = temp.flatten.map { |x| 
              if (x == symbol['symbol']) 
                replace_image
              else
                x
              end
            }
          end
        end

        il = ImageList.new

        text.delete('')

        # run a space through to get the text height
        dr, tt = draw_text(
          'text',
          {
            'x' => 0,
            'y' => 0,
            'color' => field['color'],
            'sizex' => field['sizex']
          },
          nil,
          {'text' => '.', 'aspect' => 'c'},
          nil
        )

        height = dr.get_type_metrics('.').height
        min = tt.measurements['rows']
        textlength = 0

        text.each_with_index do |item, i|
          if (item.class == SizeImage)
            sc = min/item.measurements['rows']
            item.measurements['columns'] *= sc
            item.measurements['rows'] *= sc

            textlength += item.measurements['columns']*sc
          else
            textlength += dr.get_type_metrics(item).width
          end
        end

        scale = field['sizey'] ?
          (field['sizex']*field['sizey']*@dpi**2)/height/textlength : 1
        scale = [scale, 1].min

        # get new draw obj
        dr, _ = draw_text(
          'text',
          {
            'x' => 0,
            'y' => 0,
            'color' => field['color'],
            'sizex' => field['sizex'],
            'scale' => scale
          },
          nil,
          {'text' => '.', 'aspect' => 'c'},
          nil
        )

        lines = break_text_with_image(field['sizex']*@dpi, text, dr)

        lines.each_with_index do |line, i|
          tempimlist = ImageList.new

          line.each do |item|
            im = nil
 
            if (item.class == SizeImage)
              im = item.image.resize(
                scale*item.measurements['columns'],
                scale*item.measurements['rows']
            )
            else
              dr, im = draw_text(
                'text',
                {
                  'x' => 0,
                  'y' => 0,
                  'color' => field['color'],
                  'rotate' => 0,
                  'sizex' => field['sizex'],
                  'scale' => scale
                },
                nil,
                {'text' => item, 'aspect' => card['aspect']},
                drawHash
              )
              im = im.image
              dr.draw(im)
            end

            tempimlist << im
          end

          tempimg = tempimlist.append(false)
          case field['align']
          when 'center'
            pad = ((field['sizex']*@dpi) - tempimg.bounding_box.width)/2
          when 'right'
            pad = ((field['sizex']*@dpi) - tempimg.bounding_box.width)
          else
            pad = 0
          end

          tempimlist.destroy!
          tempimlist = ImageList.new 

          unless (pad.zero?)
            padimg = Image.new(
              pad,
              tempimg.bounding_box.height
            ) {
              self.background_color = 'none'
            }
            tempimlist << padimg
          end

          tempimlist << tempimg

          il << tempimlist.append(false)
          tempimlist.destroy!
        end

        pos = relative_to_value(drawHash, field, card)
        output = il.append(true)
        il.destroy!

        rotate_image!(field, output)
        image.composite!(output, pos['x'], pos['y'], OverCompositeOp)
      end
    end

    # Rotates drawing and translates coordinates back to "normal"
    # Mutates d
    def rotate_drawing!(field, d, pos)
      if (field['rotate'])
        d.rotate(field['rotate'])
        d.translate(
          *rotate_coords(
            pos['x'],
            pos['y'],
            -field['rotate']
          )
        )
      else
        d.translate(
          pos['x'],
          pos['y'],
        )
      end
    end

    # Rotates image
    # Mutates image
    def rotate_image!(field, image)
      if (field['rotate'])
        image.background_color = 'none'
        image.rotate!(field['rotate'])
      end
    end

    # Traverses relative fields and calculates the correct position
    # Returns the value calculated
    def relative_to_value(drawHash, field, card)
      pos = {}
      {'x' => 'width', 'y' => 'height'}.each do |a, b|
        attribute = field[a]
        pos[a] = 0

        while (!attribute.is_a?(Numeric))
          o, f = attribute.split('.')
          attribute = @fields[o][f]

          if (@fields[o]['type'] == 'text')
            if (card[o])
              bt = break_text(
                (field['sizex']*@dpi).floor,
                card[o],
                drawHash[o]
              )

              pos[a] += drawHash[o].get_multiline_type_metrics(bt)[b]
            end
          else
            pos[a] += @fields[o]['size' + f]*@dpi
          end
        end

        pos[a] += (attribute*@dpi).floor
      end

      return pos
    end

    # Adjusts size to compensate for the resize from rotate_image
    # Mutates size[x] and size[y]
    def adjust_size!(size, rotate)
      unless (rotate) then return end

      if (rotate % 180 > 90)
        size['x'], size['y'] = size['y'], size['x']
      end

      rotate %= 90
      rotate *= Math::PI/180

      ['x', 'y'].each do |a|
        size[a] *= Math.sin(rotate) + Math.cos(rotate)
      end
    end

    # Breaks text based on the given width
    # Returns \n-broken text
    def break_text(width, text, draw)
      result = []
      line = ''
      t = text.split(' ')

      t.each_with_index do |word, i|
        if (draw.get_type_metrics(line + ' ' + word).width > width)
          result << line
          line = word
        else
          line += ' ' unless (i == 0)
          line += word
        end
      end

      unless (line.empty?)
        result << line
      end

      return result.join("\n")
    end

    # Breaks textarray based on the given width
    # Returns nested array
    def break_text_with_image(width, textarray, draw)
      tokens = textarray.flat_map{ |x| x.respond_to?(:split) ? x.split(' ') : x }

      result = []
      line = []
      linelength = 0

      tokens.each_with_index do |item, i|
        itemlength = item.class == SizeImage ?
          item.measurements['columns'] : draw.get_type_metrics(item + ' ').width

        if (itemlength + linelength > width)
          result << line
          line = [item]
          linelength = itemlength
        else
          if (!line.empty?)
            t = line.pop

            if (t.class != SizeImage)
              t += ' '
            end
            
            if (t.class == SizeImage or item.class == SizeImage)
              line << t << item

              line << ' ' if (i != tokens.length - 1)
            else
              line << t + item
            end
          else
            line << item
          end

          linelength += itemlength
        end
      end

      unless (line.empty?)
        result << line
      end

      return result
    end

    def scale_down(text, size, d)
      if (size['sizey'].nil?)
        return 1
      end

      # scale down
      if (size['sizex'])
        m = d.get_type_metrics(text)
        scale = m.width*m.height/size['sizex']/@dpi
        y = size['sizey']*@dpi

        return [y/scale, 1].min
      end

      raise 'No sizey and/or sizex!'
    end

    # Rotates provided coords by deg
    # Returns [x', y']
    def rotate_coords(x, y, deg)
      d = deg * Math::PI / 180

      return [
        x*Math.cos(d) - y*Math.sin(d),
        x*Math.sin(d) + y*Math.cos(d)
      ]
    end

    # Reverse maps strings to RMagick constants
    # Returns the RMagick constant
    def to_constant(str)
      case str
      when 'left'
        return LeftAlign
      when 'right'
        return RightAlign
      when 'center'
        return CenterAlign
      end
    end
end
