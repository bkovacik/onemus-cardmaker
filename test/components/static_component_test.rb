require 'rspec'
require 'rmagick'

require_relative '../../lib/components/static_component'

DPI = 72

describe 'draw static text' do
  context "always" do
    it "creates an image based on the static text" do
      image = create_static().draw(DPI)

      generatedImagePixels = image.export_pixels_to_str
      testImagePixels = Image.read('./test/images/text_with_28_chars.png').first.export_pixels_to_str

      expect(generatedImagePixels).to(eq(testImagePixels))
    end
  end
end

# Should be mostly covered by the text tests. Just want to make sure that text is created from the proper location.
def create_static()
  imagepath = File.expand_path(File.dirname(__FILE__) + '/../images')

  return StaticComponent.new(
    'text',
    {
      'sizex'   => 0,
      'textsize'=> 0.35,
      'text'    => 'text'
    },
    {
      'text'    => '',
    },
    'Verdana',
    {},
    '',
    [{
      'symbol'  => '`d',
      'replace' => '/base_image.png',
      'image'   => true,
      'fields'  => [ 'text' ]
    }],
    imagepath,
    {
      'text'  => 'some text `d test `d asdfsdf'
    }
  )
end
