require 'rmagick'
require 'yaml'

class CardListRenderer
  def initialize(args)
    confdir = File.expand_path('../config', File.dirname(__FILE__))
    @cardList = YAML.load_file(confdir + args['cardlist'])

    @tile = args['tile']

    @padding = args['padding']

    @dpi = args['dpi'] ? args['dpi'] : @layout['dpi']

    @outdir = File.expand_path(args['outdir'], File.dirname(__FILE__))
    @outpath = File.expand_path(args['outdir'] + '/*.png', File.dirname(__FILE__))

    @imageCache = {}
    Dir[@outpath].each{ |x|
      @imageCache[x[/.*\/(.*)\.png/, 1]] = Image.read(x).first
    }
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
    cardX = @cardX
    cardY = @cardY
    padding = @padding

    output = imageList.montage{
      self.geometry = "#{cardX}x#{cardY}#{padding}"
      self.tile = tile
    }
    output.units = Magick::PixelsPerInchResolution
    output.x_resolution = @dpi

    output.write(File.expand_path(@outdir + name, File.dirname(__FILE__)))
  end

end
