# Takes worksheet and parses it
# Returns a hash of cards SheetName => CardName => Card
# Modifies defaultFile

def read_worksheet(ws, defaultFile)
  cards = {}
  keys = []
  (1..ws.num_rows).each do |row|
    if (row == 1)
      cards[ws.title] = {}
    end

    card = {}

    (1..ws.num_cols).each do |col|
      if ws[row, col].empty? then next end

      # first row should be keys
      if (row == 1)
        keys << ws[row, col].gsub(' ', '_').downcase
      else
        card[keys[col-1]] = ws[row, col]
      end
    end

    unless (card.empty?)
      cards[ws.title][card['name']] = card
    end

    if (defaultFile and card['count'])
      defaultFile['cards'] << card.select do |field|
        ['name', 'count'].include?(field)
      end
    end
  end

  return cards
end
