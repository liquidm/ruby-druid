module Druid
  class Having
    def method_missing(name, *args)
      if args.empty?
        HavingClause.new(name)
      end
    end
  end

  class HavingClause

    (instance_methods + private_instance_methods).each do |method|
      unless method.to_s =~ /^(__|instance_eval|instance_exec|initialize|object_id|raise|puts|inspect|class)/ || method.to_s =~ /\?/
        undef_method method
      end
    end

    include Serializable

    def initialize(metric)
      @metric = metric
    end

    def <(value)
      @type = "lessThan"
      @value = value
      self
    end

    def >(value)
      @type = "greaterThan"
      @value = value
      self
    end

    def to_hash
      {
        :type => @type,
        :aggregation => @metric,
        :value => @value
      }
    end
  end

  class HavingOperator
    include Serializable

    def initialize(type)
      @type = type
      @elements = []
    end

    def add(element)
      @elements << element
    end

    def to_hash
      {
        :type => @type,
        :havingSpecs => @elements
      }
    end
  end
end
