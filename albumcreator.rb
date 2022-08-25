# -*- coding: utf-8 -*-
# Die Idee stammt von [[http://www.lostfocus.de/archives/2008/01/22/time-in-your-life/][Dominik Schwinds Weblog]] aus dem Jahr 2008.

require 'net/http'
require 'rmagick'
include Magick

# A list of fonts to choose from
FONT_DIRS = ["fonts", "/usr/share/fonts/*/**"]
fontlist = []
for fdir in FONT_DIRS
  fontlist += Dir.glob(fdir).select{|name|
    ext = File.extname(name)
    [".ttf", ".otf"].member?(ext)
  }
end
fontlist = [""] if fontlist.empty? # choose the standard font if none available

def https_get(uri_string)
  uri = URI(uri_string)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  # http.verify_mode = OpenSSL::SSL::VERIFY_NONE   # for sites with bad certificates
  return http.request(Net::HTTP::Get.new(uri.request_uri))
end

def get_artist
  good = false
  while not good
    good = true
    artist = https_get("https://en.wikipedia.org/wiki/Special:Random")['location']
    artist = artist.match("[^/]*$")[0]
    artist = artist.sub(/[,(].*$/, '').gsub(/_/, ' ',)
    # I want neither "List of ..." ...
    if (artist.start_with?("List of ")) then good = false; end
    # nor something starting with more than 3 numbers in the beginning (like "1986 lake wobegon softball championship")
    # ("257ers" would be okay, though)
    if artist.match(/^[0-9.-]{4}/) then good = false; end
  end
  # Unescape URL chars (e.g. %3F) and remove trailing spaces
  return URI.decode_www_form_component(artist).strip
end

def get_album
  album = Net::HTTP.get(URI("http://www.quotationspage.com/random.php"))
  album = album.to_enum(:scan, /<dt class="quote"><a [^>]*>(.*)<\/a>\s*<\/dt>/).map{Regexp.last_match}.sample[1]
  album = album.match(/( [^ ]*){4}\.$/)[0]
  album = album[1..-2]

  # Filter out unfitting first words
  good = false
  while not good
    good = true
    for word in ["are", "and", "be", "can", "It", "it", "is", "me", "of", "or", "that", "than", "them", "to", "us", "were"]
      if album.start_with?(word+" ")
        album = album[(word.length()+1)..-1]
        good = false
      end
    end
  end
  return album
end

MIN_FONTSIZE=8
MAX_FONTSIZE=50
# TODO: Sometimes goes into an endless loop.
def adjust_fontsize(text, font, maxwidth, minwidth=0)
  d = Draw.new
  fontsize = MAX_FONTSIZE
  resize_step = ((MAX_FONTSIZE-MIN_FONTSIZE)/2)
  width = -1
  while (width < minwidth or width > maxwidth)
    d.font = font;
    d.pointsize = fontsize;
    cwidth = d.get_type_metrics(text).width
    #puts "fontsize #{fontsize} yields width #{cwidth}."
    if (cwidth > maxwidth) then fontsize -= resize_step; resize_step/=1.5; next; end
    if (cwidth < minwidth) then fontsize += resize_step; resize_step/=1.5; next; end
    if (fontsize > MAX_FONTSIZE) then fontsize = MAX_FONTSIZE; end
    if (fontsize < MIN_FONTSIZE) then fontsize = MIN_FONTSIZE; end
    break;
  end
  return fontsize
end

def get_image_url
  # Find a nice image on flickr
  image_url = https_get("https://www.flickr.com/explore/interesting/7days/").body
  image_url_idx = image_url.index('<a href="/photos/')
  image_url = image_url.match(/<a data-track="thumb".*<\/a>/)[0] # find the first image
  image_url = image_url.match(/img src=\"[^\"]*\"/)[0]           # locate the image URL
  image_url = image_url[9..image_url.length-2]
  image_url = image_url.sub('_m.jpg', '.jpg')                    # we don't want the thumbnail, but the full image
  return image_url
end

# Get artist name, album title and image
artist = get_artist
album  = get_album
puts "#{artist}: #{album}"
image_url = get_image_url
image = https_get(image_url).body
File.new("image.jpg", "w").write(image)

# Randomly choose some fonts
# TODO: What if the artist contains non-ASCII chars the font does not support?
# TODO: allow different random-weights for fonts?
albumfont  = fontlist[rand*fontlist.size]
artistfont = fontlist[rand*fontlist.size]

# Prepare image comment
comment = "Generated by Album Cover Generator, written 2013-2016 by Hendrik Radke.\n"
comment+= "Idea by Dominik Schwind, http://www.lostfocus.de/archives/2008/01/22/time-in-your-life/"
comment+= "Text: #{artist}: #{album}"
comment+= "Fonts used: #{artistfont}: #{albumfont}"
comment+= "Image used: "+ image_url

# Prepare the image and add comments
img = ImageList.new("image.jpg").cur_image
img_size = [img.rows, img.columns].max
img2 = Image.new(img_size, img_size) {|img|
  img.background_color = 'black'
  img.comment = comment # Fixmenot: Does not work for some strange reason. Workaround below.
}
img2[:comment] = comment

# position the image in a rectangular frame
composite_op = ReplaceCompositeOp
if (img.rows > img.columns)
  # too slim images might be positioned on the left or right border, or in the middle
  rnd = rand()
  if    (rnd <= 0.4)     # Position image left
    img2.composite!(img, 0, 0, composite_op)
  elsif (rnd <= 0.8)     # Position image right
    img2.composite!(img, img.rows-img.columns, 0, composite_op)
  else #(rnd <= 1.0)     # Position image centered
    img2.composite!(img, (img.rows-img.columns)/2, 0, composite_op)
  end
elsif (img.columns > img.rows)
  # too wide images are centered.
  img2.composite!(img, 0, (img.columns-img.rows)/2, composite_op)
else
  # for perfectly square images
  img2.composite!(img, 0, 0, composite_op)
end

albumfontsize  = adjust_fontsize(album, albumfont, img2.columns * 0.9, img2.columns * 0.3)
artistfontsize = adjust_fontsize(artist, artistfont, img2.columns * 0.9, img2.columns * 0.4)

d = Draw.new
d.annotate(img2, 0,0,0,8, artist) {|img|
  img.font = artistfont
  img.fill = 'white'
  img.stroke = 'white'
  img.pointsize = artistfontsize
  img.font_weight = BoldWeight
  img.gravity = NorthEastGravity
}

d.annotate(img2, 0,0,4,8, album) {|img|
  img.font = albumfont
  img.fill = 'white'
  img.stroke = 'transparent'
  img.pointsize = albumfontsize
  img.font_weight = NormalWeight
  img.gravity = SouthGravity
}

img2.write("covers/#{artist}-#{album}.jpg")
