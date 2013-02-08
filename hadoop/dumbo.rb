require 'set'
require 'json'
require 'erb'
require './lib/hdfs_scanner.rb'
require './lib/s3_scanner.rb'

base_dir = File.dirname(__FILE__)

state_file_name = File.join(base_dir, 'hadoop_state.json')
template_file = File.join(base_dir, 'importer.template')

hadoop_state = JSON.parse(IO.read(state_file_name)) rescue {}
template = ERB.new(IO.read(template_file))

hdfs = Druid::HdfsScanner.new :file_pattern => '/events/*/*/*/*/part*', :cache => hadoop_state
hdfs.scan

raw_start, raw_end = hdfs.range
raw_start = (raw_start / 3600).floor * 3600 # start at the hour boundary
raw_end = [raw_end, (Time.now.to_i / 3600).floor * 3600].min # cut off at the last full hour

puts "We got raw data from #{Time.at raw_start} to #{Time.at raw_end}"

segments = {}

ii = raw_start
while ii <= raw_end
  segments[ii] = nil
  ii += 3600
end

s3 = Druid::S3Scanner.new :bucket => 'madvertise-druid', :prefix => '/hadoop', :data_source => 'madvertise'

s3.scan.each do |s3_segment|
  start = s3_segment['start']
  if segments.include? start
    segments[start] = s3_segment
  else
    puts "Ignoring s3 segment for #{Time.at(start).utc} as it's not in the raw data range"
  end
end

rescan_hours = Set.new
rescan_files = Set.new

segments.each do |start, info|
  hdfs_files = hdfs.files_for start, info
  if (hdfs_files.length > 0)
    rescan_hours.add start
    rescan_files.merge hdfs_files
  elsif info.nil?
    puts "No raw data available for #{Time.at(start). utc}, laggy HDFS importer?"
  end
end

intervals = rescan_hours.map do |time|
  "#{Time.at(time).utc.iso8601}/#{Time.at(time+3600).utc.iso8601}"
end
files = rescan_files.to_a

puts 'Writing template'

IO.write(state_file_name, hdfs.to_json)
IO.write(File.join(base_dir, 'druidimport.conf'), template.result(binding))

puts 'And we are out'
