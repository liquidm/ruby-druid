module Druid
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
end