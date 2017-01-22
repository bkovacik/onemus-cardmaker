require 'rmagick'
require 'yaml'
include Magick

DEFAULT_TEXT_SIZE = 0.15
FONT_DIR = 'C:/Windows/Fonts/'

class CardRenderer
  # Args[0] = colors
  # Args[1] = layout
  # Args[2] = cardList
  # Args[3] = outdir
  def initialize(*args)
    confdir = File.expand_path('../config', File.dirname(__FILE__))
    @colors = YAML.load_file(confdir + args[0])
    @layout = YAML.load_file(confdir + args[1])['layout']
    @cardList = YAML.load_file(confdir + args[2])
    @outdir = args[3]

    @imageCache = {}

    @dpi = @layout['dpi']

    @aspects = @colors['aspects']

    @globals = @colors['globals']

    @fields = @layout['fields'] 

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

    draw(c, card)

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

    imageList.montage{
      self.geometry = "#{@cardX}x#{@cardY}+2+2"
      self.tile = "3x3"
    }.write(File.expand_path(@outdir + name, File.dirname(__FILE__)))
  end

  private
    # Draws a card to image
    def draw(image, card) 
      drawHash = {};

      @fields.each do |name, field|
        d = Draw.new
        color = field['color']
        drawHash[name] = d
        pos = {}

        if (field['type'] == 'text')
          d.interline_spacing = -5
          d.pointsize = field['textsize'].nil? ?
            DEFAULT_TEXT_SIZE*@dpi : field['textsize']*@dpi
        end

        d.fill = @globals[color].nil? ?
          @aspects[card['aspect']]['color'][color] : @globals[color]
        font = FONT_DIR +
          (field['font'].nil? @layout['font'] : field['font']) +
          '.ttf'
        unless File.file?(font)
          raise "#{font} not found!"
        else
          d.font = font 
        end

        # relative fields
        {'x' => 'width', 'y' => 'height'}.each do |a, b|
          attribute = field[a]
          pos[a] = 0

          while (!attribute.is_a?(Numeric))
            o, f = attribute.split('.')
            attribute = @fields[o][f]

            if (@fields[o]['type'] == 'text')
              unless (card[o].nil?)
                broken_text = break_text(
                  (field['sizex']*@dpi).floor,
                  card[o],
                  drawHash[o]
                )
                pos[a] += drawHash[o].get_multiline_type_metrics(broken_text)[b]
              end
            else
              pos[a] += @fields[o]['size' + f]*@dpi
            end
          end

          pos[a] += (attribute*@dpi).floor
        end

        # default color
        unless (aspect = card['aspect'])      
          card['aspect'] = 'c'
        end

        # rotate
        unless (field['rotate'].nil?)
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

        case field['type']
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
        when 'text'
          unless (card[name].nil?)
            d.text(
              0,
              0,
              break_text(
                (field['sizex']*@dpi).floor,
                card[name],
                d
              )
            )
          else
            next
          end
        else
          raise "Invalid type field for #{name}!"
        end

        d.draw(image)
      end

      @imageCache[card['name']] = image
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
          line += word
        end

        if (i != t.size - 1)
          line += ' '
        end
      end

      unless (line.empty?)
        result << line
      end

      return result.join("\n")
    end
end
