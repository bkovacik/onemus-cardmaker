require 'rspec'
require 'rmagick'

require_relative '../../lib/components/rectangle_component'
require_relative '../../lib/components/rounded_component'

DPI = 72

describe 'draw rectangle' do
  ['rectangle', 'rounded'].each do |round|
    context "30x40 #{round}" do
      it "draws a #{round} with 30x40 sides" do
        image = create_rectangle(30.0/DPI, 40.0/DPI, round).draw(DPI)

        generatedImagePixels = image.export_pixels_to_str
        testImagePixels = Image.read("./test/images/30x40_#{round}.png").first.export_pixels_to_str

        expect(generatedImagePixels).to(eq(testImagePixels))
      end
    end
  end
end

def create_rectangle(width, height, round)
  if (round == 'rounded')
    return RoundedComponent.new(
      '',
      {
        'sizex' => width,
        'sizey' => height,
        'round' => 0.15
      },
      {},
      {},
      {}
    )
  end

  return RectangleComponent.new(
    '',
    {
      'sizex' => width,
      'sizey' => height
    },
    {},
    {},
    {}
  )
end
