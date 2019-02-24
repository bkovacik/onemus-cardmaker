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
          create_polygon(n, 0).draw(DPI)
        }.to(raise_error(RuntimeError))
      end
    end
  end

  [true, false].each do |rounded|
    roundString = rounded ? 'rounded' : 'sharp'
    GOODSIDES.each do |n|
      context "#{n} #{roundString} sides" do
        it "draws a polygon with #{n} #{roundString} sides" do
          image = create_polygon(n, rounded).draw(DPI)

          generatedImagePixels = image.export_pixels_to_str
          testImagePixels = Image.read("./test/images/#{n}gon_#{roundString}.png").first.export_pixels_to_str

          expect(generatedImagePixels).to(eq(testImagePixels))
        end
      end
    end
  end
end

def create_polygon(n, rounded)
  round = rounded ? 0.15 : 0.0
  return PolyComponent.new(
    '',
    {
      'side'  => 1,
      'round' => round
    },
    {},
    n,
    {},
    {},
  )
end
