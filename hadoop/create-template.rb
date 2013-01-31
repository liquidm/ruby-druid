#!/usr/bin/env ruby

require 'time'
require 'erb'

base_dir = File.dirname(__FILE__)
now = (ARGV.size > 0 ? Time.parse(ARGV.join(' ')) : Time.now).utc

end_time = Time.new(now.year, now.month, now.day, now.hour, 0, 0).utc
start_time = (end_time - 3600).utc # one hour ago
last_time = (start_time - 3600).utc # one hour earlier

template = ERB.new(File.read(File.join(base_dir, 'importer.template')))

puts "#{start_time.utc.iso8601}/#{end_time.utc.iso8601}"
File.open(File.join(base_dir, 'druidimport.conf'), 'w') { |file| file.write(template.result(binding)) }
