module Druid
  class Having
    def method_missing(name, *args)
      if args.empty?
        HavingClause.new(name)
      end
    end
  end

  class HavingFilter
    include Serializable

    def clause?
      is_a?(HavingClause)
    end

    def operator?
      is_a?(HavingOperator)
    end
  end

  class HavingClause < HavingFilter
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

  class HavingOperator < HavingFilter
    def initialize(type)
      @type = type
      @elements = []
    end

    def and?
      @type == 'and'
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
