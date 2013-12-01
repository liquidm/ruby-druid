require 'parslet'

module Druid
  module SQL
    class Transform < Parslet::Transform
      rule(value: simple(:value)) { value.to_s }
      rule(identifier: simple(:value)) { value.to_s }
      rule(string: simple(:value)) { value.to_s }
      rule(number: simple(:number)) {
        value = Float(number)
        value = value.to_i if value % 1.0 == 0
        value
      }
      rule(aggregate: { type: simple(:type), field: simple(:field) }) {
        { fieldAccess: Aggregate.new(type, field) }
      }
      rule(fieldAccess: simple(:aggregate)) {
        FieldAccessPostAggregate.new(aggregate)
      }
      rule(constant: simple(:constant)) {
        ConstantPostAggregate.new(constant)
      }
      rule(arithmetic: { left: simple(:left), op: simple(:op), right: simple(:right) }) {
        ArithmeticPostAggregate.new(op, [left, right])
      }
      rule(expression: simple(:expression), name: simple(:name)) {
        expression.name = name
        expression
      }
      rule(interval: { start: simple(:start), stop: simple(:stop) }) {
        Interval.new(start, stop)
      }
      rule(granularity: simple(:granularity)) {
        Granularity.new(granularity)
      }
      rule(dimension: simple(:dimension)) {
        Dimension.new(dimension)
      }
    end

    # helper for temporary columns
    class OutputColumn
      @@counter = 0
      def self.next
        "__temp_column#{@@counter += 1}"
      end
    end

    # query builder
    class GroupByQuery
      attr_accessor :query

      def initialize(opts = {})
        @opts = opts
        @query = {}
        @query[:queryType] = 'groupBy'
        @query[:dataSource] = opts[:source].to_s
        @query[:granularity] = "all"
        set_intervals
        #set_filter
        set_groups
        set_aggregations
      end

      def set_intervals
        @query[:intervals] = []
        [@opts[:intervals]].flatten.each do |interval|
          interval.set(@query)
        end
      end

      def set_groups
        @query[:dimensions] = []
        [@opts[:groups]].flatten.compact.each do |group|
          group.set(query)
        end
      end

      def set_aggregations
        @query[:aggregations] = []
        @opts[:expression].set(query)
      end

    end

    # ast nodes
    class Dimension
      attr_accessor :dimension

      def initialize(dimension)
        @dimension = dimension.to_s
      end

      def set(query)
        query[:dimensions] << @dimension
      end
    end

    class Granularity
      attr_accessor :granularity

      def initialize(granularity)
        @granularity = granularity.to_s
      end

      def set(query)
        query[:granularity] = granularity
      end
    end

    class Interval
      attr_accessor :start
      attr_accessor :stop

      def initialize(start, stop)
        @start = start
        @stop = stop
      end

      def set(query)
        today = Time.now.to_date.to_time
        @start = today + @start if @start.is_a?(Fixnum)
        @stop = today + @stop if @stop.is_a?(Fixnum)
        @start = DateTime.parse(@start.to_s) unless @start.respond_to?(:iso8601)
        @stop = DateTime.parse(@stop.to_s) unless @stop.respond_to?(:iso8601)
        query[:intervals] << "#{@start.iso8601}/#{@stop.iso8601}"
      end
    end

    class Aggregate
      attr_accessor :type
      attr_accessor :field
      attr_accessor :name

      def initialize(type, field, name = nil)
        @type = type
        @field = field unless @type == 'count'
        @name = name || OutputColumn.next
      end

      def to_h
        {
          type: @type.to_s,
          name: @name,
          fieldName: @field,
        }
      end
    end

    class PostAggregate
      attr_reader :type
      attr_accessor :name

      def initialize(name = nil)
        @name = name || OutputColumn.next
      end

      def to_h(query = nil)
        {
          type: @type.to_s,
          name: @name
        }
      end

      def set(query)
        query[:postAggregations] = [to_h(query)]
      end
    end

    class ConstantPostAggregate < PostAggregate
      attr_accessor :value

      def initialize(value, name = nil)
        super(name)
        @type = :constant
        @value = value
      end

      def to_h(query = nil)
        super.merge({
          value: @value
        })
      end
    end

    class FieldAccessPostAggregate < PostAggregate
      attr_accessor :field

      def initialize(aggregate, name = nil)
        @name = name || aggregate.name
        @type = :fieldAccess
        @aggregate = aggregate
      end

      def to_h(query = nil)
        if query
          query[:aggregations] << @aggregate.to_h
        end
        super.merge({
          fieldName: @aggregate.name
        })
      end
    end

    class ArithmeticPostAggregate < PostAggregate
      attr_accessor :fn
      attr_accessor :fields

      def initialize(fn, fields, name = nil)
        super(name)
        @type = :arithmetic
        @fn = fn
        @fields = fields
      end

      def to_h(query = nil)
        super.merge({
          fn: @fn,
          fields: @fields.map { |f| f.to_h(query) },
        })
      end
    end

    class JavascriptPostAggregate < PostAggregate
      attr_accessor :fn
      attr_accessor :field

      def initialize(function, fieldNames, name = nil)
        super(name)
        @type = :javascript
        @fn = fn
        @fields = fields
      end

      def to_h(query = nil)
        super.merge({
          function: @fn,
          fieldNames: @fields.map { |f| f.to_h(query) },
        })
      end
    end
  end
end
