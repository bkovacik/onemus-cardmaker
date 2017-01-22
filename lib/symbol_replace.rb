# Takes in card data and and outputs a version with all the symbols replaced
# Returns a hash of cards SheetName => CardName => Card

def symbol_replace(cards)
  confdir = File.expand_path('../config', File.dirname(__FILE__))
  s = YAML.load_file(confdir + '/symbols.yaml')
  symbols = s['symbols']

  carddata = cards.values[0]

  carddata.each do |name, card|
    symbols.each do |symbol|
      symbol['fields'].each do |ability|
        unless (card[ability].nil?)
          if (symbol['field'] and !card[symbol['replace']].nil?)
            card[ability] = card[ability].gsub(symbol['symbol'], card[symbol['replace']])
          elsif (!symbol['field'].nil?)
            card[ability] = card[ability].gsub(symbol['symbol'], symbol['replace'])
          end
        end
      end
    end
  end

  return cards
end
