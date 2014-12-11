require 'time'

module Druid
  class BaseQuery
    include Serializable

    DURATION_MAPPING = {
      'minute' => 'PT1M',
      'fifteen_minute' => 'PT15M',
      'thirty_minute' => 'PT30M',
      'hour' => 'PT1H',
      'day' => 'P1D',
    }.freeze

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
        if %w{all none}.include?(granularity_s)
          @granularity = granularity_s
          return self
        else
          @granularity = {
            type: :period,
            period: DURATION_MAPPING[granularity_s] || granularity_s,
          }
          @granularity[:timeZone] = time_zone if time_zone
        end
      end

      @granularity[:origin] = origin if origin
      self
    end

    def interval(from, to = Time.now)
      intervals([[from, to]])
    end

    alias_method :[], :interval

    def intervals(intervals)
      @intervals = intervals.map {|params| create_interval(*params) }
      self
    end

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

    protected

    def create_interval(from, to)
      now = Time.now
      from = now + from if from.is_a?(Fixnum)
      to = now + to if to.is_a?(Fixnum)

      "#{from.iso8601}/#{to.iso8601}"
    end

  end
end
