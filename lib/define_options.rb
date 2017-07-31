require 'optparse'

class DefineOptions
  Dimension = Struct.new(:x, :y)
  Padding = String.new

  def initialize(options)
    ARGV << '-h' if ARGV.empty?

    OptionParser.new do |opts|
      opts.default_argv = [
        '--gamedir=/onemus',
        '--colors=/colors.yaml',
        '--cardlayout=/cardlayout.yaml',
        '--cardlist=/cardlist.yaml',
        '--cardlistname=/output.png',
        '--symbols=/symbols.yaml',
        '--images=images/',
        '--statictext=/statictext.yaml',
        '--outdir=../output/',
        '--padding=+2+2'
      ] + ARGV

      opts.banner = "Usage: cardmaker(.rb) [options]\nAll paths are relative!"

      opts.accept(Dimension, /(\d+x\d+|\d+x|x\d+)/)
      opts.accept(Padding, /(\+\d+\+\d+)/)

      opts.on('--name=NAME', String, 'Name of Google Drive document') do |n|
        options['name'] = n
      end

      opts.on('--colors=COLORS', String, 'Path to colors definition') do |c|
        options['colors'] = c
      end

      opts.on('--cardlist=CARDLIST', String, 'Path to cardlist') do |c|
        options['cardlist'] = c
      end

      opts.on('--cardlistname=CARDLISTNAME', String, 'Name of cardlist') do |c|
        options['cardlistname'] = c
      end

      opts.on('--cardlayout=CARDLAYOUT', String, 'Path to cardlayout') do |c|
        options['cardlayout'] = c
      end

      opts.on('--symbols=SYMBOLS', String, 'Path to symbols') do |s|
        options['symbols'] = s
      end

      opts.on('--images=IMAGES', String, 'Path to images') do |i|
        options['images'] = i
      end

      opts.on('--statictext=TEXT', String, 'Path to statictext') do |t|
        options['statictext'] = t
      end

      opts.on('-o=OUTDIR', '--outdir=OUTDIR', String, 'Output directory') do |o|
        options['outdir'] = o
      end

      opts.on('-c', '--clean', 'Clean directory before exporting') do |c|
        options['clean'] = c
      end

      opts.on('--sheets=SHEETS', Array, 'Which sheets to export. Defaults to all') do |s|
        options['sheets'] = s 
      end

      opts.on('--dpi=DPI', Integer, 'DPI of exported images') do |d|
        options['dpi'] = d
      end

      opts.on('--tile=DIMENSION', Dimension, 'How cards are arranged in output') do |t|
        options['tile'] = t
      end

      opts.on('--pad=PADDING', '--padding=PADDING', Padding, 'Padding around the cards') do |p|
        options['padding'] = p
      end

      opts.on('--gamedir=DIRECTORY', String, 'Game directory') do |g|
        options['gamedir'] = g
      end

      opts.on('--nogen', "Don't generate card images") do |n|
        options['nogen'] = n
      end

      opts.on('-p', '--print', 'Output cards in sheet form') do |p|
        options['print'] = true
      end

      opts.on('-v', '--verbose', 'Verbose') do |v|
        options['verbose'] = true
      end

      opts.on('-h', '--help', 'Show this message') do
        puts opts
        exit
      end
    end.parse!
  end
end
