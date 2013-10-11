module Druid

  class ResponseRow
    (instance_methods + private_instance_methods).each do |method|
      unless method.to_s =~ /^(__|object_id|initialize)/
        undef_method method
      end
    end

    attr_reader :timestamp
    attr_reader :row

    def initialize(row)
      @timestamp = row['timestamp']
      @row = row['event'] || row['result']
    end

    def method_missing(name, *args, &block)
      @row.send name, *args, &block
    end

    def to_s
      "#{@timestamp.to_s}:#{@row.to_s}"
    end

    def inspect
      "#{@timestamp.inspect}:#{@row.inspect}"
    end

  end

end
