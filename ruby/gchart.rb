#!/usr/bin/env ruby
#

require 'rubygems'
#require 'google_chart'
require 'gchart'

require 'parse'

class AltitudeChart

  attr_reader :points,:track

  NumPoints = 100
  Size = "500x300"
  Xsize = 500
  Ysize = 300

  def initialize(track)
    d = track.distance
    delta = track.distance.to_f / NumPoints
    upto = delta
    index = 1
    points = []
    points << track.first.elev.to_i
    while upto < track.distance
      # Find the point after the 'upto' location
      while track[index].total_distance < upto
        index += 1
        last if index >= track.size
      end
      last if index >= track.size

      # We need to add a value, the altitude should be taken from between
      # track[index-1] and track[index]
      upto += delta
      points << track[index].elev.to_i
    end

    @points = points
    @track = track
  end

  # The input is an array of arrays, which are [distance, grade, speed]
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
    l.to_url
  end

  def url_gchart
    min = (@points.min.to_i / 100 * 100)
    max = ((@points.max.to_i+100) / 100 * 100)

    scale = 4000.0 / (max - min).to_f
    shifted_points = @points.map { |p| (p - min) * scale }

    gc = GChart.line do |g|
      g.data = shifted_points
      g.colors = [:red ]
      g.width = Xsize
      g.height = Ysize

      g.axis(:bottom) do |a|
        a.range = 0 .. (@track.distance.to_i/1000)
      end

      g.axis(:right) do |a|
        a.range = min .. max
      end
    end
    gc.to_url
  end

  alias_method :url, :url_gchart

end

ff =  GChart.line(:data => [0, 10, 100])

ARGV.each do |file|
  tracks = Gpx.new(file) do |track|
    chart = AltitudeChart.new(track)
    puts '<img class="gchart" src="' + chart.url + '">"'
#    system("konqueror '" + chart.url + "'")
  end

  

end
