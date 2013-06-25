require 'time'
require 'json'

module Druid
  class Query

    attr_reader :properties

    def initialize(source, client = nil)
      @properties = {}
      @client = client

      # set some defaults
      data_source(source)
      granularity(:all)

      interval(today)
    end

    def today
      Time.now.to_date.to_time
    end

    def send
      @client.send(self)
    end

    def query_type(type)
      @properties[:queryType] = type
      self
    end

    def data_source(source)
      source = source.split('/')
      @properties[:dataSource] = source.last
      @service = source.first
      self
    end

    def source
      "#{@service}/#{@properties[:dataSource]}"
    end

    def group_by(*dimensions)
      query_type(:groupBy)
      @properties[:dimensions] = dimensions.flatten
      self
    end

    [:long_sum, :double_sum].each do |method_name|
      agg_type = method_name.to_s.split('_')
      agg_type[1].capitalize!
      agg_type = agg_type.join

      define_method method_name do |*metrics|
        query_type(:groupBy)
        aggregations = @properties[:aggregations] || []
        aggregations.concat(metrics.flatten.map{ |metric|
          {
            :type => agg_type,
            :name => metric.to_s,
            :fieldName => metric.to_s
          }
        }).uniq!
        @properties[:aggregations] = aggregations
        self
      end
    end

    alias_method :sum, :long_sum

    def postagg(type=:long, &block)
      post_agg = PostAggregation.new.instance_exec(&block)
      @properties[:postAggregations] ||= []
      @properties[:postAggregations] << post_agg

      # make sure, the required fields are in the query
      field_type = (type.to_s + '_sum').to_sym
      # ugly workaround, because SOMEONE overwrote send
      sum_method = self.method(field_type)
      sum_method.call(post_agg.get_field_names)

      self
    end

    def postagg_double(&block)
      postagg(:double, &block)
    end

    def filter(hash = nil, &block)
      if hash
        last = nil
        hash.each do |k,values|
          filter = FilterDimension.new(k).in(values)
          last = last ? last.&(filter) : filter
        end
        @properties[:filter] = @properties[:filter] ? @properties[:filter].&(last) : last
      end
      if block
        filter = Filter.new.instance_exec(&block)
        raise "Not a valid filter" unless filter.is_a? FilterParameter
        @properties[:filter] = @properties[:filter] ? @properties[:filter].&(filter) : filter
      end
      self
    end

    def interval(from, to = Time.now)
      intervals([[from, to]])
    end

    def intervals(is)
      @properties[:intervals] = is.map{ |ii| mk_interval(ii[0], ii[1]) }
      self
    end

    alias_method :[], :interval

    def granularity(gran, time_zone = nil)
      gran = gran.to_s
      case gran
      when 'none', 'all', 'minute', 'fifteen_minute', 'thirty_minute', 'hour'
        @properties[:granularity] = gran
        return self
      when 'day'
        gran = 'P1D'
      end

      time_zone ||= Time.now.strftime('%Z')
      # druid doesn't seem to understand 'CEST'
      # this is a work around
      time_zone = 'Europe/Berlin' if time_zone == 'CEST'

      @properties[:granularity] = {
        :type => 'period',
        :period => gran,
        :timeZone => time_zone
      }
      self
    end

    def to_json
      @properties.to_json
    end

    private

    def mk_interval(from, to)
      from = today + from if from.is_a?(Fixnum)
      to = today + to if to.is_a?(Fixnum)

      from = DateTime.parse(from.to_s) unless from.respond_to? :iso8601
      to = DateTime.parse(to.to_s) unless to.respond_to? :iso8601
      "#{from.iso8601}/#{to.iso8601}"
    end

  end

  class PostAggregation
    def method_missing(name, *args)
      if args.empty?
        PostAggregationField.new(name)
      end
    end
  end

  module PostAggregationOperators
    def +(value)
      PostAggregationOperation.new(self, :+, value)
    end

    def -(value)
      PostAggregationOperation.new(self, :-, value)
    end

    def *(value)
      PostAggregationOperation.new(self, :*, value)
    end

    def /(value)
      PostAggregationOperation.new(self, :/, value)
    end
  end

  class PostAggregationOperation
    include PostAggregationOperators

    attr_reader :left, :operator, :right, :name

    def initialize(left, operator, right)
      @left = left.is_a?(Numeric) ? PostAggregationConstant.new(left) : left
      @operator = operator
      @right = right.is_a?(Numeric) ? PostAggregationConstant.new(right) : right
    end

    def as(field)
      @name = field.name.to_s
      self
    end

    def get_field_names
      field_names = []
      field_names << left.get_field_names if left.respond_to?(:get_field_names)
      field_names << right.get_field_names if right.respond_to?(:get_field_names)
      field_names
    end

    def to_hash
      hash = { "type" => "arithmetic", "fn" => @operator, "fields" => [@left.to_hash, @right.to_hash] }
      hash["name"] = @name if @name
      hash
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end

    def as_json(*a)
      to_hash
    end
  end

  class PostAggregationField
    include PostAggregationOperators

    attr_reader :name

    def initialize(name)
      @name = name
    end

    def get_field_names
      @name
    end

    def to_hash
      { "type" => "fieldAccess", "name" => @name, "fieldName" => @name }
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end

    def as_json(*a)
      to_hash
    end
  end

  class PostAggregationConstant
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def to_hash
      { "type" => "constant", "value" => @value }
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end

    def as_json(*a)
      to_hash
    end
  end

  class FilterParameter
    (instance_methods + private_instance_methods).each do |method|
      unless method.to_s =~ /^(__|instance_eval|instance_exec|initialize|object_id|raise|puts|inspect|class)/ || method.to_s =~ /\?/
        undef_method method
      end
    end
  end

  class Filter
    (instance_methods + private_instance_methods).each do |method|
      unless method.to_s =~ /^(__|instance_eval|instance_exec|initialize|object_id|raise|puts|inspect)/ || method.to_s =~ /\?/
        undef_method method
      end
    end

    def method_missing(method_id, *args)
      FilterDimension.new(method_id)
    end
  end

  class FilterDimension < FilterParameter
    def initialize(name)
      @name = name
      @value = nil
      @regexp = nil
    end

    def eq(value)
      return self.in(value) if value.is_a? Array
      return self.regexp(value) if value.is_a? Regexp
      @value = value
      self
    end

    alias :'==' :eq


    def neq(value)
      return !self.in(value)
    end

    alias :'!=' :neq

    def in(*args)
      values = args.flatten
      raise "Must provide non-empty array in in()" if values.empty?

      if (values.length == 1)
        return self.eq(values[0])
      end

      filter_or = FilterOperator.new('or', true)
      values.each do |value|
        raise "query is too complex" if value.is_a? FilterParameter
        param = FilterDimension.new(@name)
        param.eq value
        filter_or.add param
      end
      filter_or
    end

    def &(other)
      filter_and = FilterOperator.new('and', true)
      filter_and.add(self)
      filter_and.add(other)
      filter_and
    end

    def |(other)
      filter_or = FilterOperator.new('or', true)
      filter_or.add(self)
      filter_or.add(other)
      filter_or
    end

    def !()
      filter_not = FilterOperator.new('not', false)
      filter_not.add(self)
      filter_not
    end

    def regexp(r)
      r = Regexp.new(r) unless r.is_a? Regexp
      @regexp = r.inspect[1...-1] #to_s doesn't work
      self
    end

    def to_hash
      raise 'no value assigned' unless @value.nil? ^ @regexp.nil?
      hash = {
        :dimension => @name
      }
      if @value
        hash['type'] = 'selector'
        hash['value'] = @value
      elsif @regexp
        hash['type'] = 'regex'
        hash['pattern'] = @regexp
      end
      hash
    end

    def to_s
      to_hash.to_s
    end

    def as_json(*a)
      to_hash
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end
  end

  class FilterOperator < FilterParameter
    def initialize(name, takes_many)
      @name = name
      @takes_many = takes_many
      @elements = []
    end

    def add(element)
      @elements.push element
    end

    def &(other)
      if @name == 'and'
        filter_and = self
      else
        filter_and = FilterOperator.new('and', true)
        filter_and.add(self)
      end
      filter_and.add(other)
      filter_and
    end

    def |(other)
      if @name == 'or'
        filter_or = self
      else
        filter_or = FilterOperator.new('or', true)
        filter_or.add(self)
      end
      filter_or.add(other)
      filter_or
    end

    def !()
      if @name == 'not'
        @elements[0]
      else
        filter_not = FilterOperator.new('not', false)
        filter_not.add(self)
        filter_not
      end
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end

    def as_json(*a)
      to_hash
    end

    def to_s
      to_hash.to_s
    end

    def as_json(options)
      to_hash
    end

    def to_hash
      result = {
        :type => @name
      }
      if @takes_many
        result[:fields] = @elements.map(&:to_hash)
      else
        result[:field] = @elements[0].to_hash
      end
      result
    end
  end
end
