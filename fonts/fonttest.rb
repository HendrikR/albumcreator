# -*- coding: utf-8 -*-

# A list of fonts to choose from
FONT_SIZE = 12
FONT_DIR = "./"
LINEDIST = 6
fontlist = Dir.new(FONT_DIR).select{|name| name.upcase.end_with?(".TTF")}
fontlist.map!{|name| FONT_DIR + name}
fontlist << "" if fontlist.empty? # choose the standard font if none available

require 'rmagick'
include Magick

def fonttext(font)
  font + ": äbç..xÿz"
end

img_width, img_height = [0, 0]

d = Draw.new{
    self.fill = 'white'
    self.stroke = 'white'
    self.pointsize = FONT_SIZE
    self.font_weight = NormalWeight
    self.gravity = NorthWestGravity
}

for font in fontlist do
  d.font = font
  metrics = d.get_type_metrics(fonttext(font))
  img_width  = [img_width, metrics.width].max
  img_height += metrics.height + LINEDIST
end

# Prepare the image and add comments
img = Image.new(img_width, img_height) {
  self.background_color = 'black'
}

y = 0
for font in fontlist do
  d.font = "Helvetica" # Warning: Danger of Helvetica Scenario!
  metrics = d.get_type_metrics(font)
  d.annotate(img, 0,0,0,y, font)
  d.annotate(img, 0,0,metrics.width,y, fonttext("")) {
    self.font = font
  }
  y += metrics.height + LINEDIST
end

img.write("fonttest.png")
