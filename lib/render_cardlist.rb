require 'rmagick'
require 'yaml'
require 'objspace'
require 'combine_pdf'

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

  def render_cardlist(name, outdir)
    imageList = ImageList.new

    tileX, tileY = /(\d+)x(\d+)/.match(@tile).captures
    cardsPerPage = tileX.to_i * tileY.to_i

    index = 0
    @cardList['cards'].each do |card|
      (1..card['copies']).each_with_index do |copy, index|
        imageList << get_image(card['name'])

        if (index%cardsPerPage == cardsPerPage - 1)
          render_page(imageList, outdir + name, (index/cardsPerPage).to_s)
          imageList.clear()

          GC.start
        end
      end
    end

    if (imageList.length)
      render_page(imageList, outdir + name, (index/cardsPerPage).to_s)
      imageList.clear()

      GC.start
    end
  end

  def render_pdf(name, outdir)
    images = Dir[@outdir + outdir + '/*.png']

    imageDims = images.map do |x|
      Image.ping(x).first
    end

    x = imageDims.max_by(&:columns).columns
    y = imageDims.max_by(&:rows).rows

    pdf = CombinePDF.new
    images.each_with_index do |image, index|
      imageData = Image.read(image).first

      pdfName = image.sub('.png', '.pdf')
      imageData.border((x-imageData.columns)/2, (y-imageData.rows)/2, 'white')
        .write(pdfName)

      pdf << CombinePDF.load(pdfName)

      imageData = nil
      GC.start
    end

    FileUtils.rm(Dir[@outdir + outdir + '/*.pdf'])
    pdf.save(@outdir + outdir + '/output.pdf')
  end

  private
    def render_page(imageList, name, pageNum)
      tile = @tile
      cardX = @cardX
      cardY = @cardY
      padding = @padding

      output = imageList.montage do |list|
        list.geometry = "#{cardX}x#{cardY}#{padding}"
        list.tile = tile
      end
      output.units = Magick::PixelsPerInchResolution
      output.x_resolution = @dpi

      output.write(
        File.expand_path(
          @outdir + name + pageNum + '.png',
          File.dirname(__FILE__)
        )
      )
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
