require 'google_drive'
require_relative 'read_worksheet'
require_relative 'render_card'

if (ARGV.empty?)
  raise "Usage: (ruby) cardmaker(.rb) [GOOGLE DRIVE FILENAME]\n #{ARGV.length}"
end

docname = ARGV[0].freeze
confpath = File.expand_path('../config/config.json', File.dirname(__FILE__))
session = GoogleDrive::Session.from_config(confpath)

unless (file = session.file_by_title(docname))
  raise "File #{docname} not found!" 
end

cards = {}
file.worksheets.each do |ws|
  cards = cards.merge(read_worksheet(ws))
end

cards.each do |title, card|
  card.each do |t, c|
    render_card(c)
  end
end
