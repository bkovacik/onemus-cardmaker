# Takes in card data and and outputs a version with all the symbols replaced
# Returns a hash of cards SheetName => CardName => Card

def symbol_replace(cards)
  confdir = File.expand_path('../config', File.dirname(__FILE__))
  s = YAML.load_file(confdir + '/symbols.yaml')
  symbols = s['symbols']

  carddata = cards.values[0]

  carddata.each do |name, card|
    symbols.each do |symbol|
      symbol['fields'].each do |field|
        if (card[field] and !symbol['image'].nil? and !symbol['image'])
          if (card[symbol['replace']])
            card[field] = card[field].gsub(symbol['symbol'], card[symbol['replace']])
          else
            card[field] = card[field].gsub(symbol['symbol'], symbol['replace'])
          end
        end
      end
    end
  end

  return cards
end
