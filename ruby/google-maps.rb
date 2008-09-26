#!/usr/bin/env ruby

require 'rubygems'

class GoogleMaps

  def initialize(name,points)
    @name = name.gsub(/ +/,'_')
    @points = points
    @mid_lat =  points.inject(0.0) do |sum,cords|
      sum += cords[0] 
    end / points.size
    @mid_long = points.inject(0.0) do |sum,cords|
      sum += cords[1]
    end / points.size

    puts @mid_lat
    puts @mid_long

  end

  def to_html
    str =<<EOF
  function overlay_#{@name}(map) {
	  var polyline = new google.maps.Polyline([
EOF
    @points.each do |p|
      str << "new google.maps.LatLng(#{p[0]},#{p[1]}),\n"
    end
    str.chop!
    str.chop!
    str +=<<EOF
  ],"#ff0000",3,0.5);
	map.addOverlay(polyline);
  }
EOF
  end

end

