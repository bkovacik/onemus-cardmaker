require 'rspec'
require 'rmagick'

require_relative '../../lib/components/image_component'

#Override DPI, so set DPI to 1
BASEIMAGESIZE = 32
IMAGETILES = [
  {
    rows: 1,
    cols: 3
  },
  {
    rows: 3,
    cols: 1
  },
  {
    rows: 2.5,
    cols: 0.5
  }, 
  {
    rows: 2,
    cols: 2
  }
]

describe 'tile image' do
  IMAGETILES.each do |props|
    rows = props[:rows]
    cols = props[:cols]

    context "#{rows}x#{cols}" do
      it "returns an image with #{rows} rows and #{cols} columns" do
        image = create_tiled_image(rows, cols).draw(1)

        generatedImagePixels = image.export_pixels_to_str
        testImagePixels = Image.read("./test/images/base_image_#{rows}x#{cols}.png").first.export_pixels_to_str

        expect(generatedImagePixels).to(eq(testImagePixels))
      end
    end
  end
end

describe 'crop' do
  rows = 0.5
  cols = 0.5

  context "#{rows}x#{cols}" do
    it "returns an image with #{rows} rows and #{cols} columns" do
      image = create_cropped_image(rows, cols).draw(1)

      generatedImagePixels = image.export_pixels_to_str
      testImagePixels = Image.read("./test/images/base_image_crop_#{rows}x#{cols}.png").first.export_pixels_to_str

      expect(generatedImagePixels).to(eq(testImagePixels))
    end
  end
end

describe 'resize' do
  rows = 2 
  cols = 3

  context "#{rows}x#{cols}" do
    it "returns an image with #{rows} rows and #{cols} columns" do
      image = create_resized_image(rows, cols).draw(1)

      generatedImagePixels = image.export_pixels_to_str
      testImagePixels = Image.read("./test/images/base_image_resize_#{rows}x#{cols}.png").first.export_pixels_to_str

      expect(generatedImagePixels).to(eq(testImagePixels))
    end
  end
end

def create_tiled_image(rows, cols)
  return ImageComponent.new(
    '',
    {
      'sizex' => cols*BASEIMAGESIZE,
      'sizey' => rows*BASEIMAGESIZE,
      'tile'  => true,
      'tilex' => BASEIMAGESIZE,
      'tiley' => BASEIMAGESIZE
    },
    {},
    {},
    {},
    File.expand_path('./test/images/base_image.png')
  )
end

def create_cropped_image(rows, cols)
  return ImageComponent.new(
    '',
    {
      'sizex' => cols*BASEIMAGESIZE,
      'sizey' => rows*BASEIMAGESIZE,
      'crop'  => true
    },
    {},
    {},
    {},
    File.expand_path('./test/images/base_image.png')
  )
end

def create_resized_image(rows, cols)
  return ImageComponent.new(
    '',
    {
      'sizex' => cols*BASEIMAGESIZE,
      'sizey' => rows*BASEIMAGESIZE,
    },
    {},
    {},
    {},
    File.expand_path('./test/images/base_image.png')
  )
end
