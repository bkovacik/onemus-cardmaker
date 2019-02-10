require_relative 'base_component'

class TextComponent < BaseComponent
  def initialize(name, field, card, font, globals, aspects, symbols, images)
    super(name, field, card, globals, aspects)

    @font = font
    @globals = globals
    @aspects = aspects
    @symbols = symbols
    @images = images
    @text = [card[name]]

    @fontDir = 'C:/Windows/Fonts/'
    @defaultTextSize = 0.12
  end

  def draw(dpi)
    return super(dpi) if @text.first.nil?

    d = create_new_drawing()
    font = @fontDir +
      (@field['font'].nil? ? @font : @field['font']) +
      '.ttf'
    unless File.file?(font)
      raise "#{font} not found!"
    else
      d.font = font 
    end

    il = ImageList.new

    text = replace_with_symbols(@text, @name)
    text.delete('')

    fontsize = @field['textsize'] ?
      @field['textsize']*dpi : @defaultTextSize*dpi
    d.pointsize = fontsize

    height = d.get_type_metrics('.').height
    textlength = 0

    # Normalize textstring and get resulting width
    text.each_with_index do |item, i|
      if (item.class == Image)
        sc = height/item.rows
        item.resize!(sc)

        textlength += item.columns
      else
        textlength += d.get_type_metrics(item).width
      end
    end

    scale = @field['sizey'] ?
      (@field['sizex']*@field['sizey']*dpi**2)/height/textlength : 1
    scale = [scale, 1].min

    d.pointsize = fontsize*scale
    d.gravity = Magick::SouthWestGravity

    width = @field['sizex'] ? @field['sizex']*dpi : 0

    lines = break_text_with_image(width, text, d)

    # Append and align text
    lines.each_with_index do |line, i|
      tempimlist = ImageList.new

      populate_imglist!(line, tempimlist, d, scale)

      tempimg = tempimlist.append(false)

      case @field['align']
        when 'center'
          pad = ((@field['sizex']*dpi) - tempimg.columns)/2
        when 'right'
          pad = ((@field['sizex']*dpi) - tempimg.columns)
        else
          pad = 0
      end
      pad = pad.to_i

      tempimlist.destroy!
      tempimlist = ImageList.new 

      unless (pad.zero?)
        padimg = Image.new(pad, tempimg.rows) {
          self.background_color = 'transparent'
        }
        tempimlist << padimg
      end

      tempimlist << tempimg

      il << tempimlist.append(false)
      tempimlist.destroy!
    end

    output = il.append(true)
    il.destroy!

    return output
  end

  protected
    # Takes in array containing a string and the name of the field
    # Returns array of text and symbols 
    def replace_with_symbols(text, name)
      @symbols.each do |symbol|
        if (symbol['image'] and symbol['fields'].include?(name))
          temp = []

          text.each_with_index do |token, i|
            if (token.class == Image)
              temp.push(token)
            elsif (!token.empty?)
              tokens = token.split(/(#{symbol['symbol']})/)
              temp.push(*tokens)
            end
          end

          imagepath = @images + symbol['replace']

          m = Image.ping(imagepath).first
          replace_image = Image.read(imagepath).first

          text = temp.flatten.map { |x| 
            if (x == symbol['symbol']) 
              replace_image
            else
              x
            end
          }
        end
      end

      return text
    end

    # Breaks textarray based on the given width
    # Returns nested array
    def break_text_with_image(width, textarray, draw)
      tokens = textarray.flat_map{ |x| x.respond_to?(:split) ? x.split(/ /) : x }
      tokens = tokens.flat_map{ |x| x.respond_to?(:split) ? x.split(/(?<=\n)/) : x }

      result = []
      line = []
      linelength = 0

      tokens.each_with_index do |item, i|
        itemlength = item.class == Image ?
          item.columns : draw.get_type_metrics(item + ' ').width

        if (line.empty?)
          line << item
        else
          if (width != 0 && itemlength + linelength > width)
            result << line
            line = [item]
            linelength = 0
          else
            t = line.pop

            if (t.class != Image)
              t += ' '
            elsif (item.class != Image)
              item = ' ' + item
            end
            
            if (t.class == Image or item.class == Image)
              line << t << item
            else
              line << t + item
            end
          end
        end

        if (item.class != Image and item.include?("\n"))
          line[0].sub!("\n", '')
          result << line
          line = []
          linelength = 0
          next
        end

        linelength += itemlength
      end

      unless (line.empty?)
        result << line
      end

      return result
    end

    # Takes in a line and an image list to populate with token images from the line
    # Mutates tempimlist
    def populate_imglist!(line, tempimlist, d, scale)
      spaceWidth = d.get_type_metrics('a a').width - d.get_type_metrics('aa').width
      line.each do |item|
        im = nil

        if (item.class == Image)
          im = item.resize(scale)
          im.background_color = 'transparent'
        else
          trimItem = item.gsub(/^ */, '')
          numSpaces = item.length - trimItem.length
          metrics = d.get_type_metrics(trimItem)

          im = Image.new(
            metrics.width + spaceWidth * numSpaces,
            metrics.height
          ) {
            self.background_color = 'transparent'
          }

          dr = d.clone
          dr.text(0, 0, item)
          dr.draw(im)
        end

        tempimlist << im
      end
    end
end
