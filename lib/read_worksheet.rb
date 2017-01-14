def read_worksheet(ws)
  cards = {}
  keys = []
  (1..ws.num_rows).each do |row|
    if (row == 1)
      cards[ws.title] = []
    end

    card = {}  

    (1..ws.num_cols).each do |col|
      if ws[row, col].empty? then next end

      # first row should be keys
      if (row == 1)
        keys << ws[row, col]
      else
        card[keys[col-1]] = ws[row, col]
      end
    end
    
    unless (card.empty?)
      cards[ws.title] << card
    end
  end

  return cards 
end
