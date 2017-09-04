require 'rmagick'
require 'yaml'
require 'objspace'

class CardListRenderer
  CACHESIZE = 10

  def initialize(args)
    confdir = File.expand_path('../config' + args['gamedir'], File.dirname(__FILE__))
    @cardList = YAML.load_file(confdir + args['cardlist'])

    @tile = args['tile']

    @padding = args['padding']

    @dpi = args['dpi'] ? args['dpi'] : @layout['dpi']

    @outdir = File.expand_path(args['outdir'], File.dirname(__FILE__))
    @outpath = File.expand_path(args['outdir'] + '/*.png', File.dirname(__FILE__))

    @imageCache = {}
    @images = Dir[@outpath].map do |x|
      x[/.*\/(.*)\.png/, 1]
    end
  end

  def render_cardlist(name)
    imageList = ImageList.new

    tileX, tileY = /(\d+)x(\d+)/.match(@tile).captures
    cardsPerPage = tileX.to_i * tileY.to_i

    index = 0
    @cardList['cards'].each do |card|
      (1..card['copies']).each do |copy|
        imageList << get_image(card['name'])

        if (index%cardsPerPage == cardsPerPage - 1)
          render_page(imageList).write(
            File.expand_path(
              @outdir + name + (index/cardsPerPage).to_s + '.png',
              File.dirname(__FILE__)
            )
          )

          imageList.clear()
          GC.start
        end

        index += 1
      end
    end

    render_page(imageList)
  end

  private
    def render_page(imageList)
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

      return output
    end

    def get_image(name)
      if (@images.include?(name))
        if (@imageCache.length >= CACHESIZE)
          @imageCache.delete(@imageCache.keys[0])
        end

        @imageCache[name] = Image.read(@outdir + '/' + name + '.png').first
      else
        raise "No image for card #{name} found!"
      end

      return @imageCache[name]
    end
end
