require 'rspec'
require 'rmagick'

require_relative '../../lib/components/aspect_icon_component'

DPI ||= 72

ASPECTS = ['n', 'a', 'e']

describe 'draw aspect icons' do
  ASPECTS.each do |aspect|
    context "#{aspect}" do
      it "creates a distinct image for #{aspect}" do
        image = create_aspect_icon(aspect).draw(DPI)

        generatedImagePixels = image.export_pixels_to_str
        testImagePixels = Image.read("./test/images/aspect_icon_#{aspect}.png").first.export_pixels_to_str

        expect(generatedImagePixels).to(eq(testImagePixels))
      end
    end
  end
end

def create_aspect_icon(aspect)
  return AspectIconComponent.new(
    '',
    {
      'images' => {
        aspect => '/' + aspect + '.png'
      }
    },
    {
      'aspect' => aspect
    },
    {},
    {},
    File.expand_path('./test/images')
  )
end
