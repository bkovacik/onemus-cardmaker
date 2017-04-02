require 'google_drive'
require 'fileutils'
require_relative 'read_worksheet'
require_relative 'render_card'
require_relative 'symbol_replace'
require_relative 'define_options'

options = {}
DefineOptions.new(options)

docname = options['name']
confpath = File.expand_path('../config/config.json', File.dirname(__FILE__))
session = GoogleDrive::Session.from_config(confpath)

unless (file = session.file_by_title(docname))
  raise "File #{docname} not found!" 
end

cards = {}
worksheets = file.worksheets.dup
if (options['sheets'])
  worksheets.select! { |sheet| options['sheets'].include?(sheet.title) }
end
worksheets.each do |ws|
  cards = cards.merge(symbol_replace(read_worksheet(ws)))
end

r = CardRenderer.new(options)

if options['clean']
  FileUtils.rm_rf(Dir['./output/*'])
end

cards.each do |title, card|
  print "\n#{title} ======\n" if options['verbose']

  card.each do |t, c|
    print "#{t}\n" if options['verbose']

    r.render_card(c)
  end
end

if options['print']
  FileUtils.mkdir_p('./output/output')
  r.render_cardlist('/output/output.png')
end
