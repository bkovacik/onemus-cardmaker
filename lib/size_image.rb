require 'rmagick'
include Magick

class SizeImage
  attr_accessor :image, :measurements

  # Args[0] = image
  # Args[1] = measurements
  def initialize(*args)
    @image = args[0]
    @measurements = args[1]
  end
end
