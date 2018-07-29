#!/usr/bin/env ruby

require 'date'
require 'pathname'

ARGV.each do |filename|
  fp = Pathname.new(filename)
  dir = fp.dirname
  base_name = fp.basename

  if m = base_name.to_s.match(/^(.*?.gpx)(.gpx)+$/)
    base_name = Pathname.new(m[1]).basename
    change = true
  end

  r = open(filename).read.gsub(/\n/,"")
  if m = r.match(/<trkseg>.*?<time>([^<]+)<\/time>/)
    date = DateTime.parse(m[1])
    date += Rational(10,24)
    local = date.strftime("%Y-%m-%d")
    localu = date.strftime("%Y_%m_%d")
    rlocal = date.strftime("%d-%m-%Y")
    rlocalu = date.strftime("%d_%m_%Y")

    if m = base_name.to_s.match(/((#{local}|#{localu}|#{rlocal}|#{rlocalu})[-_ ]+)+(.*?)$/)
      base_name = Pathname.new(m[3])
      change = true
    end

    if m = base_name.to_s.match(/^(#{local}-){2,}(.*)$/)
      base_name = Pathname.new(m[2])
      change = true
    end

    new_name = dir + "#{local + '-' + base_name.to_s}"
   # puts("#{filename} -> #{new_name}") if change
    File.rename(filename, new_name) if filename != new_name
  end
end
