class Float
  def to_radians
    Math::PI * self / 180.0
  end

  def to_bearing
    ((self * 180.0 / Math::PI) + 360) % 360
  end
end

class GpsPoint
  require 'time'
  include Math

  EarthRadius = 6371000.0 # in meters

  attr_accessor :lat,:long, :elev, :time

  def initialize(lat = 0.0,long = 0.0, elev = 0.0, time = nil)

    unless lat.kind_of? Hash
      @lat = lat.to_f
      @long = long.to_f
      @elev = elev.to_f
      @time = load_time time
    else
      @lat =  0.0
      @long =  0.0
      @elev =  0.0
      @time = nil
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

  # Return the distance in meters between 2 points, calculated using the
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
  alias distance distance_haversine

  def distance_spherical(p)
    o_lat = lat.to_radians
    p_lat = lat.to_radians
    d_long = (p.long - @long).to_radians

    d = acos(sin(o_lat) * sin(p_lat) + cos(o_lat) * cos(p_lat) * cos(d_long))
    d * EarthRadius
  end

  def elapsed(p)
    if time && p.time
      time - p.time
    else
      0.0
    end
  end

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

  # up elevation between the points
  def climb(p)
    @elev - p.elev
  end

  def speed_mps(p)
    t = elapsed(p)
    if t == 0.0
      0.0
    else
      (distance(p) / t).abs
    end
  end

  def speed_kmh(p)
    speed_mps(p)*60*60/1000
  end

  private 
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
end

