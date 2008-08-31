#!/usr/bin/env ruby

require 'rubygems'
require 'xmlsimple'
require 'gps-point'

$debug = true

# Class to parse Gpx format gps data files
class Gpx

  attr_accessor :tracks
  attr_accessor :way_points

  class TrackPoint
    # distance from the start
    attr_accessor :total_distance
    attr_accessor :climb
    attr_accessor :distance
    attr_accessor :grade
    attr_accessor :speed
    attr_accessor :point
    attr_accessor :name   # Generally only waypoints are named

    def elev
      @point.elev
    end
    def time
      @point.time
    end

    def initialize(gps_point = nil)
      @point = gps_point
      @total_distance = 0
      @distance = 0
      @climb = 0
      @grade = 0
      @speed = 0
      @name = ""
    end

    def to_s
      sprintf "speed = %6.2f grade = %6.2f distance = %6.1f #{time} #{@name}",
        @speed,@grade,@distance
    end
  end

  class Track < Array
    attr_accessor :name
    attr_accessor :distance
    # Amount we have climbed for the trip
    attr_accessor :climb

    def initialize(name, array = [])
      super(array)
#      puts array.size
      @name = name
    end

    def [](first, size=nil)
      return super(first) if size == nil
      self.class.new(name,Array.new(super(first,size)))
    end
  end

  def initialize(file,options = {})
    @tracks = []
    @way_points = []
    xml = XmlSimple.xml_in(file, "cache" => "storable" )

    # process the way points
    xml['wpt'] ||= []
    xml['wpt'].each do |wpt|
      point = xml_to_track_point(wpt)
      point.name = wpt['name'].to_s
      @way_points << point
#      STDERR.puts point.name
    end

    return if options[:only_waypoints]

    # process the track logs
    xml['trk'].each do |track|
      name = track['name'].to_s

      if track['trkseg']
        # process the track segment
        if track['trkseg']
          track['trkseg'].each do |track_segment|
            points = []
            ts = track_segment['trkpt']
            next unless ts.length >= 2

            last = xml_to_track_point(ts.shift)
            index = -1
            ts.each do |point|
              index += 1
              p = xml_to_track_point(point,last)

              # Sometimes we seem to get 2 points at the same time
              # In this case, throw the point away if it has the same time as the
              # next point.
              if p.time == last.time
                STDERR.puts p.time if $debug
                STDERR.puts "Dup time: #{index}" if $debug
                next 
              end

              # if we have not moved far enough, ignore the current point
              next if p.distance < 10
  
              # Sometimes we get a 'jump', if so, drop the 'segement'
              # Also if the 'grade' is too high, drop the segment
              # This is mostly supposed to stop the issue of when the
              # GPS is re-aquiring it's location
              if (p.speed > 100.0) || (options[:cycling] && (p.grade.abs > 25.0))
                if ($debug)
                  STDERR.puts "#{index}:Droping point"
                  STDERR.puts "\t" + ts[-2].to_s
                  STDERR.puts "\t" + ts[-1].to_s
                  STDERR.puts "\t" + p.to_s
                end
                next
              end

              # use this point as the next reference point
              last = p

              # If we get to here, we add the point to the track
              points << p
            end
            track = Track.new(name,points)
            next if track.length < 2
            track.climb = points.last.climb
            track.distance = points.last.total_distance
            yield track
            @tracks << track
          end
        end
      end
    end
  end

  private 
    def xml_to_track_point(h,prev = nil)
    unless !prev or prev.kind_of? TrackPoint
      raise "invalid previous point" 
    end

    if h['time'].kind_of? Array
      time = h['time'].first
    else
      time = nil
    end

    if h['ele'].kind_of? Array
      altitude = h['ele'].first.to_f
    else
      altitude = h['ele'].to_f
    end

    gp = GpsPoint.new(:longitude =>  h['lon'].to_f,
                 :latitude => h['lat'].to_f,
                 :altitude => altitude,
                 :time =>     time)
    tp = TrackPoint.new(gp)
    if prev
      tp.distance = gp.distance(prev.point)
      climb = gp.climb(prev.point)
      tp.climb = prev.climb
      tp.climb += climb if climb > 0
      tp.total_distance = prev.total_distance + tp.distance
      tp.grade = gp.grade(prev.point)
      tp.speed = gp.speed_kmh(prev.point)
    end
    tp
  end

end

if $0 == __FILE__
  ARGV.each do |file|
    points = Gpx.new(file) do |track|
      STDERR.puts "%6dm " % track.distance + "%5d:" % track.length + track.name
    end
  end
#  url = do_speed_grade(points)
#  puts url.to_s
#  system("konqueror '" + url.to_s + "'")
end
