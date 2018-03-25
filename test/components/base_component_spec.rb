require 'rspec'

require_relative '../../lib/components/base_component'

COLOR = 'base'
GLOBALBASE = '#000'
ASPECTBASE = '#FFF'

describe 'create new drawing' do
  context 'without color' do
    it 'returns a vanilla Draw obj' do
      baseComponent = BaseComponent.new('', {}, {}, {}, {})
      d = baseComponent.send(:create_new_drawing)

      expect(d.inspect).to eq('(no primitives defined)')
    end
  end

  context 'with color' do
    context 'without globals' do
      it 'returns a Draw obj with global color' do
        baseComponent = create_base_component(true, false)
        d = baseComponent.send(:create_new_drawing)

        expect(d.inspect).to eq("fill \"#{ASPECTBASE}\"")
      end
    end

    context 'with globals' do
      it 'returns a Draw obj with aspect color' do
        baseComponent = create_base_component(true, true)
        d = baseComponent.send(:create_new_drawing)

        expect(d.inspect).to eq("fill \"#{GLOBALBASE}\"")
      end
    end
  end
end

def create_base_component(color, global)
  field = {}
  field['color'] = COLOR if color

  globals = {}
  globals[COLOR] = GLOBALBASE if global

  return BaseComponent.new('', field, {
    'aspect' => 'n' 
  }, globals, {
    'n' => {
      'color' => {
        'base' => ASPECTBASE
      }
    }
  })
end
