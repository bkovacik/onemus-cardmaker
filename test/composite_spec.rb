require 'rspec'
require 'rmagick'

require_relative '../lib/render_card'
require_relative '../lib/components/icon_component'

DPI ||= 72

FIELDS = [
  {
    'field1' => {
      'type' => 'icon',
      'x' => 0,
      'y' => 0,
      'rotate' => 75,
      'image' => 'base_image.png'
    }
  }, {
    'field1' => {
      'type' => 'icon',
      'x' => 1,
      'y' => 0,
      'rotate' => 360,
      'image' => 'base_image.png'
    }
  }, {
    'field1' => {
      'type' => 'icon',
      'x' => 1,
      'y' => 1.5,
      'image' => 'base_image.png'
    },
    'field2' => {
      'type' => 'icon',
      'x' => 1,
      'y' => 'field1.y+field1.sizey',
      'rotate' => 60,
      'image' => 'base_image.png'
    }
  }, {
    'field1' => {
      'type' => 'icon',
      'x' => 1,
      'y' => 2,
      'rotate' => 225,
      'dropshadow'  => {
        'blur' => 0.2,
        'x' => -0.3,
        'y' => -0.3
      },
      'image' => 'base_image.png'
    }
  }, {
    'field1' => {
      'type' => 'icon',
      'x' => 1,
      'y' => 2,
      'rotate' => 225,
      'dropshadow'  => {
        'blur' => 0.3,
        'x' => 0.1,
        'y' => -0.2
      },
      'image' => 'base_image.png'
    }
  }
]

describe 'image rotates' do
  class CardRenderer
    def initialize(args)
      @name = args['name']
      @fields = args['fields']
      @sortedKeys = args['sortedKeys']
      @cardX = args['x']
      @cardY = args['y']
      @images = 'test/images/'
      @dpi = DPI
      @drawHash = {}
    end

    def render_card(card)
      c = Image.new(@cardX, @cardY) do |image|
        image.background_color = 'transparent'
        image.format = 'png'
      end

      draw!(c, card)

      return c
    end
  end

  FIELDS.each_with_index do |field, i|
    context field do
      it "renders the image" do
        generatedImagePixels = CardRenderer.new({
          'fields'     => field,
          'sortedKeys' => field.keys,
          'x'          => 3*DPI,
          'y'          => 3*DPI,
          'name'       => "composite_#{i}"
        }).render_card({}).export_pixels_to_str

        testImagePixels = Image.read("./test/images/composite_#{i}.png").first.export_pixels_to_str

        expect(generatedImagePixels).to(eq(testImagePixels))
      end
    end
  end
end
