require 'rmagick'
require 'google_drive'

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


if (!ARGV.length)
  print "Usage: (ruby) cardmaker(.rb) [GOOGLE DRIVE FILENAME]\n #{ARGV.length}"
end

docname = ARGV[0].freeze

session = GoogleDrive::Session.from_config("config.json")

unless (file = session.file_by_title(docname))
  raise "File #{docname} not found!" 
end

p read_worksheet(file.worksheet_by_title("Creatures"))

=begin
file.worksheets.each do |ws|
  read_worksheet(ws)
end
=end
