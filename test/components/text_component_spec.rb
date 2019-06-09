require 'rspec'
require 'rmagick'

require_relative '../../lib/components/text_component'

DPI ||= 72

TEXTBLOBS = [
  {
    image: '/base_image.png',
    text: 'some text `d test `d asdfsdf',
    sizex: 0
  }, {
    image: '/base_image.png',
    text: '`d`d`d',
    sizex: 0
  }, {
    image: '/base_image.png',
    text: 'some text `d test `d asdfsd',
    sizex: 1
  }, {
    image: '/long_image.png',
    text: 'some text `d test `d asdfdss `d',
    sizex: 40
  }, {
    image: '/base_image.png',
    text: 'some `d test `d asdfsdf',
    sizex: 0,
    stroke: 0.02
  }
]

ALIGNMENTS = [
  'center',
  'left',
  'right'
]

describe 'text line breaks' do
  TEXTBLOBS.each do |x|
    context "#{x[:image]} with #{x[:text].length} chars and text box width #{x[:sizex]}" do
      it 'replaces the text symbols with image symbols and line breaks properly' do
        x[:stroke] = 0 unless x[:stroke]
        image = create_text(x[:text], x[:sizex], x[:image], 'left', x[:stroke]).draw(DPI)

        generatedImagePixels = image.export_pixels_to_str
        testImagePixels = Image.read("./test/images/text_with_#{x[:text].length}_chars.png").first.export_pixels_to_str

        expect(generatedImagePixels).to(eq(testImagePixels))
      end
    end
  end
end

describe 'text aligns' do
  ALIGNMENTS.each do |alignment|
    context "#{alignment}" do
      it "returns text aligned #{alignment}" do
        image = create_text('some sample text. really just a `d lot of text and some `d images', 3, '/base_image.png', alignment).draw(DPI)

        generatedImagePixels = image.export_pixels_to_str
        testImagePixels = Image.read("./test/images/text_aligned_#{alignment}.png").first.export_pixels_to_str

        expect(generatedImagePixels).to(eq(testImagePixels))
      end
    end
  end
end

def create_text(text, sizex, image, alignment='left', stroke=0)
  imagepath = File.expand_path(File.dirname(__FILE__) + '/../images')

  return TextComponent.new(
    'text',
    {
      'sizex'     => sizex,
      'textsize'  => 0.35,
      'align'     => alignment,
      'outline'   => {
        'color'   => 'border',
        'stroke'  => stroke
      }
    },
    {
      'text'    => text,
    },
    'Verdana',
    { 'border' => '#00F' },
    {},
    [{
      'symbol'  => '`d',
      'replace' => image,
      'image'   => true,
      'fields'  => [ 'text' ]
    }],
    imagepath
  )
end
