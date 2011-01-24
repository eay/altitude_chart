#!/usr/bin/env ruby

require 'rubygems'
require 'xmlsimple'
require 'lib/gps-point'

$debug = true

# Class to parse Gpx format gps data files
class Gpx

  # An array of tracks contained in the file
  attr_accessor :tracks
  # An array of named waypoints contained in the file
  attr_accessor :waypoints

  # This class is used to hold a waypoint from a Gpx file
  class WayPoint
    # The point
    attr_accessor :point
    # The name of the point
    attr_accessor :name

    def initialize(point,name = nil)
      @point = point
      @name = name
    end
  end

  # A Point on a track.
  class TrackPoint
    # distance from the start of the track
    attr_accessor :total_distance
    # The total climb (in meters) for the track at this point
    attr_accessor :climb
    # The distance between this point and the previous one
    attr_accessor :distance
    # The gradiant between this point and the previous one
    attr_accessor :grade
    # The speed in km/h used between this point and the previous one
    attr_accessor :speed
    # The GpsPoint of this TrackPoint
    attr_accessor :point

    # The elevation of the TrackPoint
    def elev
      @point.elev
    end

    # The time of the TrackPoint
    def time
      @point.time
    end

    # Create a new TrackPoint from a GpsPoint
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

  # A Track taken from a Gpx File
  class Track < Array
    # The name of the track
    attr_accessor :name
    # The total length of the track
    attr_accessor :distance
    # The amount of climing over the track
    attr_accessor :climb

    # Create the new Track with an optional set of points
    def initialize(name, array = [])
      super(array)
      @name = name
    end

    # Allow us to access the TrackPoints that make the track as an array
    def [](first, size=nil)
      return super(first) if size == nil
      self.class.new(@name,Array.new(super(first,size)))
    end

    def add_waypoints(waypoints)
      puts "#{waypoints.size} waypoints"
      raise "Don't call this"
    end

    # Given a Gpx::Waypoint, we return the distance into the walk that the
    # waypoint is nearest to the waypoint.  If we don't get within
    # pad metres of the waypoint, we return nil
    def waypoint_distance(waypoint,radius = 20.0)
      wpp = waypoint.point
      nearest_tp = self.first
      nearest_distance = 1000000000.0
      self.each do |tp|
        d = wpp.distance(tp.point)
        if d < nearest_distance
          nearest_distance = d
          nearest_tp = tp
        end
      end
      (nearest_distance > radius) ? nil : nearest_tp.total_distance
    end

  end

  # Create a new Gpx object.  It is passed a file name to read plus a hash
  # of options.  Valid options include
  #
  # :+only_waypoints+, which if true means we should only
  # extract waypoints from the file
  #
  # :+cycling+, which indicates that this file contains tracks from cycling.
  # We tweak some settings for throwing out invalid values.
  def initialize(file,options = {})
    @tracks = []
    @waypoints = []
    xml = XmlSimple.xml_in(file, "cache" => "storable" )

    # process the way points
    xml['wpt'] ||= []
    xml['wpt'].each do |wpt|
      point = to_way_point(wpt)
      point.name = wpt['name'].first.to_s
      @waypoints << point
#      STDERR.puts point.name
    end

    return if options[:only_waypoints]

    # process the track logs
    xml['trk'].each do |track|
      name = track['name'].first.to_s

      if track['trkseg']
        # process the track segment
        if track['trkseg']
          track['trkseg'].each do |track_segment|
            points = []
            ts = track_segment['trkpt']
            next unless ts.length >= 2

            last = to_track_point(ts.shift)
            index = -1
            ts.each do |point|
              index += 1
              p = to_track_point(point,last)

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
            yield track, @waypoints
            @tracks << track
          end
        end
      end
    end
  end

  private 

  def to_way_point(ctx)
    wp = Gpx::WayPoint.new(to_point(ctx), ctx['name'].first.to_s)
  end

  # Convert
  def to_track_point(h,prev = nil)
    unless !prev or prev.kind_of? TrackPoint
      raise "invalid previous point" 
    end
    tp = TrackPoint.new(to_point(h))
    point = tp.point
    if prev
      tp.distance = point.distance(prev.point)
      climb =       point.climb(prev.point)
      tp.climb =    prev.climb
      tp.climb += climb if climb > 0
      tp.total_distance = prev.total_distance + tp.distance
      tp.grade = point.grade(prev.point)
      tp.speed = point.speed_kmh(prev.point)
    end
    tp
  end

  def to_point(h)
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
                      :latitude =>   h['lat'].to_f,
                      :altitude =>   altitude,
                      :time =>       time)
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
