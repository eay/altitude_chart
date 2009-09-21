#!/usr/bin/env ruby
# altitude_chart.rb: Generate a png chart of distance over altitude from
# a gpx file (an XLM file containg data points from a Garmin GPS)
#
#  Usage:  ruby altitude_chart.rb [-b|-cycling] [-w|--bushwalking] [(-p|-waypoings) <waypointfile.gpx)]
#

$: << File.dirname($0)
require 'rubygems'
require 'optparse'
require 'cgi'
#require 'google_chart'
require 'gchart'

require 'net/http'

require 'lib/gpx'
require 'lib/google-maps'

# This class is used for creation of an altitude vs distance chart
class AltitudeChart

  attr_reader :points,:track

  NumPoints = 100
  Size = "500x300"
  Xsize = 700
  Ysize = 300

  # Pass in the track to render.  The waypoints are an array of [name,distance]
  # pairs
  def initialize(track,waypoints = [])
    d = track.distance
    delta = track.distance.to_f / NumPoints
    upto = delta
    index = 1
    points = []
    points << track.first.elev.to_i
    while upto < track.distance
      # Find the point after the 'upto' location
      while track[index].total_distance < upto
#        puts "#{track[index].total_distance} #{upto} #{track[index].elev.to_i}"
        index += 1
        last if index >= track.size
      end
      last if index >= track.size

      # We need to add a value, the altitude should be taken from between
      # track[index-1] and track[index]
#      puts "#{index}: #{track[index-1].point.distance(track[index].point)}"
      upto += delta
      points << track[index].elev.to_i
    end

    @waypoints = waypoints
    @points = points
    @track = track
  end

  # Generate the url to use with google charts via the gchatrb package
  # # We are not using this function right now
  def url_gchartrb
    min = (@points.min.to_i / 100 * 100)
    max = ((@points.max.to_i+100) / 100 * 100)

    scale = 4000.0 / (max - min).to_f
    shifted_points = @points.map { |p| (p - min) * scale }
#    puts shifted_points

    l = GoogleChart::LineChart.new(Size,@track.name,false) do |gc|
      gc.data_encoding = :extended
      gc.max_value(4000)
      gc.data nil, shifted_points, 'ff0000'
      gc.axis :x, :range => [0, @track.distance.to_i/1000]
      gc.axis :y, :range => [min, max]
#      puts @track.distance
      x_step = @track.distance.to_i.to_f/1000/10
      gc.grid :y_step => 100.0/((max - min)/100),
              :x_step => 100.0/x_step
#      puts @points.min.to_s + "---" + @points.max.to_s
    end
    l
  end

  # Generate the url to use with google charts using gchart
  def url_gchart(options = {})
    min = (@points.min.to_i / 100 * 100)
    max = ((@points.max.to_i+100) / 100 * 100)
    puts "min= #{min}m max= #{max}m"

    scale = 4000.0 / (max - min).to_f
    shifted_points = @points.map { |p| (p - min) * scale }

    gc = GChart.line do |g|
      km = @track.distance/1000
      climb = (@track.climb.to_i + 5)/10*10

      g.title = @track.name + (" (%.1fkm," % km) + (" %dm climbed)" % climb)
#      STDERR.puts g.title

      g.data = shifted_points
      g.colors = [:red ]
      g.width = Xsize
      g.height = Ysize

      g.axis(:bottom) do |a|
        a.range = 0 .. km
      end

      if @waypoints.size > 0
        # First, convert the distances to a percentage
        @waypoints.map! { |d| [d[0], d[1] * 100.0 / @track.distance ]}

        # Two different rows of labels, if 2 points are within 10%,
        # push the second to the second row
        top = []
        bottom = []
        last_wp = nil
        @waypoints.each do |wp|
          if last_wp and ((wp[1] - last_wp[1]) < 10)
            bottom << wp
          else
            top << wp
            last_wp = wp
          end
        end
        [bottom, top].each do |wps|
          next if wps.size == 0
          names, distances = wps.transpose

          g.axis(:top) do |a|
            a.labels = names
            a.label_positions = distances
            a.font_size = 10 
            a.text_color = :blue
          end
        end
      end

      # One step per 100m altitude
      y_step = "%.1f" % (100.0 / ((max - min)/100).to_f)
      # One step per 10km if cycling, else every 2km
      km_step = options[:cycling]?10.0:1.0
      x_step = "%.1f" % (100.0 / (km.to_f / km_step))
      g.extras.merge!("chg" => "#{x_step},#{y_step}")

      g.axis(:right) do |a|
        a.range = min .. max
      end
      g.axis(:left) do |a|
        a.range = min .. max
      end
    end
    gc
  end

  # Return a GChart object and return it
  alias_method :chart, :url_gchart

end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"
  opts.on("-w", "--bushwalking", "Bushwalking trip") do |v|
    options[:bushwalking] = v
  end
  opts.on("-b", "--cycling", "Bike ride") do |v|
    options[:cycling] = v
  end
  opts.on("-p", "--waypoints",:REQUIRED) do |v|
    options[:waypoints] = v
  end
  opts.on("-m", "--googlemaps") do |v|
    options[:googlemaps] = v
  end
end.parse!

if options[:waypoints]
  global_waypoints = Gpx.new(options[:waypoints],
                      options.merge(:only_waypoints => true)).waypoints
  puts "#{global_waypoints.size} waypoints loaded"
else
  global_waypoints = []
end

radius = options[:cycling] ? 200 : 10

ARGV.each do |file|
  tracks = Gpx.new(file,options) do |track,waypoints|
    waypoints += global_waypoints
    box = GpsBox.points(track,radius)

    tr = GpsPoint.new(box.north, box.west)
    tl = GpsPoint.new(box.north, box.east)
    br = GpsPoint.new(box.south, box.west)
    bl = GpsPoint.new(box.south, box.east)

    puts "North edge is #{"%d" % tr.distance(tl)}m"
    puts "South edge is #{"%d" % br.distance(bl)}m"
    puts "East edge is  #{"%d" % tr.distance(br)}m"
    puts "West edge is  #{"%d" % tl.distance(bl)}m"

    wps = box.inside(waypoints)
    puts "#{wps.size} waypoints in the box"
    mwps = []
    wps.each do |wp|
      d = track.waypoint_distance(wp,radius)
      mwps <<  [wp.name,d] if d
    end

    puts mwps.size
    map_waypoints = mwps.compact.sort { |a,b| a[1] <=> b[1] }
    map_waypoints.each do |name,distance|
      puts "#{name} #{"%d" % distance}"
    end


    data = AltitudeChart.new(track,map_waypoints)
    url = data.chart(options).to_url
#    puts '<img class="gchart" src="' + url + '">'
#    system("konqueror '" + chart.url + "'")
    
    puts "climb = #{"%d" % track.climb}m"
    puts "distance = #{"%d" % track.distance}m"
    image = Net::HTTP.get(URI.parse(url))
    filename = "alt_chart_" + track.name.gsub(/ +/,'_') + ".png"
    File.open(filename,"wb") do |f|
      f.write(image)
    end
    puts filename

    if options[:googlemaps]
      points = track.collect { |p| [ p.point.lat, p.point.long ] }

      gm = GoogleMaps.new(track.name,points)

      filename = "googlemaps_" + track.name.gsub(/ +/,'_') + ".js"
      File.open(filename,"wb") do |f|
        f.write(gm.to_html)
      end
    end
  end
end
