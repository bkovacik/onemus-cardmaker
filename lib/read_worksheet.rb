# Takes worksheet and parses it
# Returns a hash of cards SheetName => CardName => Card
# Modifies defaultFile

def read_worksheet(ws, defaultFile)
  cards = {}
  keys = []
  (1..ws.getNumRows()).each do |row|
    if (row == 1)
      cards[ws.getTitle()] = {}
    end

    card = {}

    (1..ws.getNumCols()).each do |col|
      cell = ws.getCell(row, col)
      if cell.empty? then next end

      # first row should be keys
      if (row == 1)
        keys << cell.gsub(' ', '_').downcase
      else
        card[keys[col-1]] = cell
      end
    end

    unless (card.empty?)
      cards[ws.getTitle()][card['name']] = card
    end

    if (defaultFile and card['count'])
      defaultFile['cards'] << card.select do |field|
        ['name', 'count'].include?(field)
      end
    end
  end

  return cards
end
