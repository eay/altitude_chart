class Float
  # Convert degrees to radians
  def to_radians
    Math::PI * self / 180.0
  end

  # convert radians to degrees
  def to_bearing
    ((self * 180.0 / Math::PI) + 360) % 360
  end
end

# This class represents a region of space with a north, south, east, west
class GpsBox
  attr_accessor :north,:south,:east,:west
  attr_reader :padding

  @@padding = 20.0

  # Specify the padding to use by default
  def self.padding(m)
    @@padding = m
  end

  # Create a new 'box' with boundaries padded by _pad_ metres
  def initialize(n,e,s,w)
    @north = n
    @east = e
    @south = s
    @west = w
    @lat_range = @south .. @north 
    @long_range = @west .. @east 
  end

  # return the passed elements that are inside the box
  def inside(array)
    array = [array] unless Array === array

    # We will return the relevent indexes from array
    unless array.first === GpsPoint
      points = array.map { |w| w.point }
    end

    ret = []
    points.each_with_index do |p,i|
#      puts "#{@lat_range} #{@long_range} #{p.lat} #{p.long}"
      if @lat_range.include?(p.lat) && @long_range.include?(p.long) 
        ret << array[i]
      end
    end
    ret
  end

  def self.point(point,padding = @@padding)
    lat,long = point.degrees_per_metre(padding)
    self.new(point.lat + lat,
             point.long + long,
             point.lat - lat,
             point.long - long)
  end
  
  def self.points(points,pad = @@padding)
    if Gpx::Track === points 
      points = points.map { |tp| tp.point }
    end
    np = points.inject { |a,b| (a.lat > b.lat) ? a : b }
    sp = points.inject { |a,b| (a.lat < b.lat) ? a : b } 
    ep =  points.inject { |a,b| (a.long > b.long) ? a : b } 
    wp =  points.inject { |a,b| (a.long < b.long) ? a : b } 
    self.new(np.lat  + GpsPoint.new(np.lat,0.0).degrees_per_metre(pad)[0],
             ep.long + GpsPoint.new(0.0, ep.long).degrees_per_metre(pad)[1],
             sp.lat  - GpsPoint.new(sp.lat,0.0).degrees_per_metre(pad)[0],
             wp.long - GpsPoint.new(0.0, wp.long).degrees_per_metre(pad)[1])
  end

  def to_s
    "#{@north}..#{@south} #{@west}..#{@east}"
  end

end

# This class holds a GPS point and contains methods for calculating distance
# and gradiant between points.
class GpsPoint
  require 'time'
  include Math

  EarthRadius = 6371000.0 # in metres

  attr_accessor :lat,:long, :elev, :time

  # Create a new point.  The arguments are ether the 4 latitude,
  # longitude, elevelation and time, or a hash containing values for :longitude,
  # :latitude, :altitude and :time
  def initialize(lat = 0.0,long = 0.0, elev = 0.0, time = nil)
    unless lat.kind_of? Hash
      @lat,@long,@elev,@time  = [lat,long,elev,time]
    else
      @lat,@long,@elev,@time  = [0.0, 0.0, 0.0, nil]
      lat.each_pair do |k,v|
        case k
        when "Longitude",:longitude
          @long = v
        when "Latitude", :latitude
          @lat = v
        when "Altitude", :altitude
          @elev = v
        when "Time",     :time
          @time = load_time v
        end
      end
    end
  end

  def longitude_cmp(point)
    @long <=> point.long
  end

  def latitude_cmp(point)
    @lat <=> point.lat
  end

  # Return the distance in metres between 2 points, calculated using the
  # Haversine formula, http://www.movable-type.co.uk/scripts/latlong.html
  def distance_haversine(p)
    d_lat  = (p.lat  - @lat).to_radians
    d_long = (p.long - @long).to_radians

    sd_lat  = sin(d_lat  / 2.0)
    sd_long = sin(d_long / 2.0)

    a = sd_lat * sd_lat +
        cos(@lat.to_radians) * cos(p.lat.to_radians) * sd_long * sd_long
    c = 2.0 * atan2(sqrt(a),sqrt(1.0 - a))
    EarthRadius * c
  end

  # This returns the distance usign the haversine algorithm
  alias distance distance_haversine

  # A different algorithm for calculating the distance between 2 points on
  # the earth.
  def distance_spherical(p)
    o_lat = lat.to_radians
    p_lat = lat.to_radians
    d_long = (p.long - @long).to_radians

    d = acos(sin(o_lat) * sin(p_lat) + cos(o_lat) * cos(p_lat) * cos(d_long))
    d * EarthRadius
  end

  # Return the number of seconds between the 2 points.
  def elapsed(p)
    if time && p.time
      time - p.time
    else
      0.0
    end
  end

  # The angle to the point.
  def bearing(p)
    d_lat  = (p.lat  - @lat).to_radians
    d_long = (p.long - @long).to_radians

    o_lat = @lat.to_radians
    p_lat = p.lat.to_radians

    y = sin(d_long) * cos(p_lat)
    x = cos(o_lat)  * sin(p_lat) - sin(o_lat) * cos(p_lat) * cos(d_long)
    atan2(y,x).to_bearing
  end

  # Grade between the points in degrees.
  def grade(p)
    d = distance(p)
    e = @elev - p.elev
    (e / d) * 100.0
  end

  # The elevation difference between the points.
  def climb(p)
    @elev - p.elev
  end

  # The speed of travel between the 2 points, in metres per second
  def speed_mps(p)
    t = elapsed(p)
    if t == 0.0
      0.0
    else
      (distance(p) / t).abs
    end
  end

  # The speed of travel between the 2 points in kilometres per hour
  def speed_kmh(p)
    speed_mps(p)*60*60/1000
  end

  # Return the number of degrees [latitude,longitude] needed to be _metres_ away
  # from the point
  def degrees_per_metre(metres)
    delta = 0.0002 # About 10-20 metres + delta
    # First to longitude
    point = self.dup
    point.long += delta
    longitude = metres.to_f * delta / distance(point)
    # Then latitude
    point = self.dup
    point.lat += delta
    latitude = metres.to_f * delta / distance(point)
    [latitude,longitude]
  end

  private 
  # Sanitize a time argument.  It can be a String, a DateTime or Nil
  def load_time(time)
    case
    when time.kind_of?(String)
      Time.parse time
    when time.kind_of?(DateTime)
      time
    when time.kind_of?(NilClass)
      nil
    else
      raise "unknown class: #{time.class}"
    end
  end

end

if $0 == __FILE__
#  p0 = GpsPoint.new(-27.515666,153.024941,33.7)
#  p1 = GpsPoint.new(-27.515695,153.024919,22.0)

  p0 = GpsPoint.new(:longitude => 153.024893,
                      :latitude => -27.514729,
                      :altitude => 26.9,
                      :time => "2007-12-07T18:43:10Z")
  p1 = GpsPoint.new(:longitude => 153.024925,
                      :latitude => -27.514597,
                      :altitude => 25.4,
                      :time => "2007-12-07T18:43:12Z")

  b = p0.bearing(p1)
  d = p0.distance(p1)
  # Distance per second
  s = p0.speed_mps(p1);
  g = p0.grade(p1)

  printf "Distance = %.2fm\n",d
  printf "Speed    = %.2f m/h\n", s * 60 * 60
  printf "Bearing  = %.2f\n", b
  printf "Grade    = %.2f\n", g

  delta = 0.0002
  p0 = GpsPoint.new(0.0,0.0,0.0)
  p1 = GpsPoint.new(0.0,delta,0.0)
  puts "#{delta} degrees latitude == #{p0.distance(p1)}m at longitude 0"
  p2 = GpsPoint.new(60.0,0.0,0.0)
  p3 = GpsPoint.new(60.0,0.0002,0.0)
  puts "#{delta} degrees latitude == #{p2.distance(p3)}m at longitude 60"

  lat,long  = p0.degrees_per_metres(20)
  puts "#{lat} #{long}"
  lat,long = p2.degrees_per_metres(20)
  puts "#{lat} #{long}"
end

