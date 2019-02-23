require 'rspec'
require 'rmagick'

require_relative '../../lib/components/poly_component'

DPI = 72

BADSIDES = [0, 1, 2]
GOODSIDES = [3, 4, 6, 7, 8]

describe 'draw polygon' do
  BADSIDES.each do |n|
    context "#{n} sides" do
      it 'raises an exception' do
        expect {
          create_polygon(n).draw(DPI)
        }.to(raise_error(RuntimeError))
      end
    end
  end

  GOODSIDES.each do |n|
    context "#{n} sides" do
      it "draws a polygon with #{n} sides" do
        image = create_polygon(n).draw(DPI)

        generatedImagePixels = image.export_pixels_to_str
        testImagePixels = Image.read("./test/images/#{n}gon.png").first.export_pixels_to_str

        expect(generatedImagePixels).to(eq(testImagePixels))
      end
    end
  end
end

def create_polygon(n)
  return PolyComponent.new(
    '',
    {
      'side' => 1,
    },
    {},
    n,
    {},
    {},
  )
end
