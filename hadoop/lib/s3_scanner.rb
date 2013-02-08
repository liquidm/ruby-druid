require 'aws/s3'
require 'time'
require 'json'

module Druid
  class S3Scanner
    def initialize(opts = {})
      @data_source = opts[:data_source] || raise('Must pass a :data_source param')
      @bucket = opts[:bucket] || raise('Must pass a :bucket param')
      @prefix = opts[:prefix] || raise('Must pass :prefix param')
      @prefix = @prefix[1..-1] if @prefix[0] == '/' # Postel's law

      AWS::S3::Base.establish_connection!({
        :access_key_id => opts[:access_key_id] || ENV['AMAZON_ACCESS_KEY_ID'],
        :secret_access_key => opts[:secret_access_key] || ENV['AMAZON_SECRET_ACCESS_KEY']
      })

      @bucket = AWS::S3::Bucket.find(@bucket)
    end

    def fetch(timestamp)
    end

    def scan
      ranges = []
      marker = ''

      begin
        puts 'Scanning S3...'
        objects = @bucket.objects(:prefix => @prefix, :marker => marker)

        objects.each do |s3object|
          marker = s3object.key
          if s3object.key.end_with? 'descriptor.json'
            descriptor = JSON.parse(s3object.value)
            if descriptor['dataSource'] == @data_source
              interval = descriptor['interval'].split('/')

              ranges.push({
                'start' => Time.parse(interval[0]).to_i,
                'end' => Time.parse(interval[1]).to_i,
                'created' => Time.parse(descriptor['version']).to_i
              })
            else
              puts "Skipping #{s3object.key} because it does not match dataSource"
            end
          end
        end
      end while objects.length > 0
      puts 'Scanning S3 completed'
      ranges
    end

  end
end

if __FILE__ == $0
  scanner = Druid::S3Scanner.new({
    :bucket => 'madvertise-druid',
    :prefix => '/hadoop',
    :data_source => 'madvertise'
  })
  puts scanner.scan.inspect
end
