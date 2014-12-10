module Druid
  class Having
    (instance_methods + private_instance_methods).each do |method|
      unless method.to_s =~ /^(__|instance_eval|instance_exec|initialize|object_id|raise|puts|inspect|send)/ || method.to_s =~ /\?/
        undef_method method
      end
    end

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

    def &(other)
      create_operator('and', other)
    end

    def |(other)
      create_operator('or', other)
    end

    def !
      create_operator('not')
    end

    def eq(value)
      set_clause('equalTo', value)
    end

    alias :'==' :eq

    def neq(value)
      !eq(value)
    end

    alias :'!=' :neq

    def <(value)
      set_clause('lessThan', value)
    end

    def >(value)
      set_clause('greaterThan', value)
    end

    def to_hash
      {
        :type => @type,
        :aggregation => @metric,
        :value => @value
      }
    end

    private

    def create_operator(type, other = nil)
      operator = HavingOperator.new(type, !other.nil?)
      operator.add(self)
      operator.add(other) if other
      operator
    end

    def set_clause(type, value)
      @type = type
      @value = value
      self
    end
  end

  class HavingOperator < HavingFilter
    def initialize(type, takes_many)
      @type = type
      @takes_many = takes_many
      @elements = []
    end

    def add(element)
      @elements << element
    end

    def &(other)
      apply_operator('and', other)
    end

    def |(other)
      apply_operator('or', other)
    end

    def !
      if @type == 'not'
        @elements.first
      else
        operator = HavingOperator.new('not', false)
        operator.add(self)
        operator
      end
    end

    def to_hash
      hash = {
        :type => @type,
      }

      if @takes_many
        hash[:havingSpecs] = @elements
      else
        hash[:havingSpec] = @elements.first
      end

      hash
    end

    private

    def apply_operator(type, other)
      if @type == type
        operator = self
      else
        operator = HavingOperator.new(type, true)
        operator.add(self)
      end
      operator.add(other)
      operator
    end
  end
end
