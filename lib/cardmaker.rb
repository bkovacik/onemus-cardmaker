require 'google_drive'
require 'fileutils'
require 'yaml'
require_relative 'read_worksheet'
require_relative 'render_card'
require_relative 'render_cardlist'
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
defaultFile = nil
worksheets = file.worksheets.dup

if (options['sheets'])
  worksheets.select! { |sheet| options['sheets'].include?(sheet.title) }
end

if (options['gen-default'])
  defaultFile = {}
  defaultFile['cards'] = []
end

worksheets.each do |ws|
  cards = cards.merge(symbol_replace(read_worksheet(ws, defaultFile), options))
end

if (options['gen-default'])
  File.open('config/default.yaml', 'w+') do |file|
    file.write(defaultFile.to_yaml)
  end
end

r = CardRenderer.new(options)

if options['clean']
  outpath = File.expand_path(options['outdir'] + '/*', File.dirname(__FILE__))
  FileUtils.rm_rf(Dir[outpath])
end

unless options['nogen']
  cards.each do |title, card|
    print "\n#{title} ======\n" if options['verbose']

    card.each do |t, c|
      print "#{t}\n" if options['verbose']

      r.render_card(c)
    end
  end
end

if options['print']
  clr = CardListRenderer.new(options)

  outdir = '/output'
  FileUtils.mkdir_p('./output' + outdir)
  clr.render_cardlist(options['cardlistname'], outdir)

  if options['pdf']
    clr.render_pdf(options['cardlistname'], outdir)
  end
end
