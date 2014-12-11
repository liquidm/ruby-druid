require 'time'

module Druid
  class BaseQuery
    include Serializable

    attr_reader :source

    def initialize(source, client = nil)
      @source = source
      @client = client

      granularity(:all)
      interval(Date.today.to_time)
    end

    def context(hash)
      @context = hash
      self
    end

    def dimensions(*dimensions)
      @dimensions = dimensions.flatten.map {|dimension| dimension.to_s }
      self
    end

    def filter(hash = nil, type = :in, &block)
      if hash
        new_filter = Filter.from_hash(hash, type)
      elsif block
        new_filter = Filter.from_block(&block)
      end

      return self unless filter

      @filter = @filter ? @filter.&(new_filter) : new_filter
      self
    end

    def granularity(granularity, time_zone = nil, origin = nil)
      if granularity.is_a?(Fixnum)
        @granularity = {
          type: :duration,
          duration: granularity * 1000,
        }
      else
        granularity_s = granularity.to_s
        if %w{all none minute fifteen_minute thirty_minute hour day}.include?(granularity_s)
          @granularity = granularity_s
          return self
        else
          @granularity = {
            type: :period,
            period: granularity_s,
          }
          @granularity[:timeZone] = time_zone if time_zone
        end
      end

      @granularity[:origin] = origin if origin
      self
    end

    def interval(from, to = Time.now)
      now = Time.now
      from = now + from if from.is_a?(Fixnum)
      to = now + to if to.is_a?(Fixnum)

      @intervals = ["#{from.iso8601}/#{to.iso8601}"]
      self
    end

    alias_method :[], :interval

    def properties
      to_hash
    end

    def send
      @client.send(self)
    end

    def to_hash
      {
        queryType: @query_type,
        dataSource: @source ? @source.split('/').last : nil,
        filter: @filter ? @filter.to_hash : nil,
        granularity: @granularity,
        intervals: @intervals,
        context: @hash,
      }
    end

  end
end