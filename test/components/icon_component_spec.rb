require 'rspec'
require 'rmagick'

require_relative '../../lib/components/icon_component'

DPI = 72

describe 'create icon' do
  context 'always' do
    it 'creates an image based on the field' do
      image = create_icon().draw(DPI)

      generatedImagePixels = image.export_pixels_to_str
      testImagePixels = Image.read("./test/images/base_image.png").first.export_pixels_to_str

      expect(generatedImagePixels).to(eq(testImagePixels))
    end
  end
end

# Should be mostly covered by the image tests. Just want to make sure that icons are created from the proper location.
def create_icon()
  return IconComponent.new(
    '',
    {
      'image' => '/base_image.png'
    },
    {},
    {},
    {},
    File.expand_path('./test/images')
  )
end
