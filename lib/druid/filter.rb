module Druid
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

  class FilterParameter
    (instance_methods + private_instance_methods).each do |method|
      unless method.to_s =~ /^(__|instance_eval|instance_exec|initialize|object_id|raise|puts|inspect|class)/ || method.to_s =~ /\?/
        undef_method method
      end
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

  class FilterDimension < FilterParameter
    def initialize(name)
      @name = name
      @value = nil
      @regexp = nil
    end

    def in_rec(bounds)
      RecFilter.new(@name, bounds)
    end 

    def in_circ(bounds)
      CircFilter.new(@name, bounds)
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

    def >(value)
      filter_js = FilterJavascript.new_comparison(@name, '>', value)
      filter_js
    end

    def <(value)
      filter_js = FilterJavascript.new_comparison(@name, '<', value)
      filter_js
    end

    def >=(value)
      filter_js = FilterJavascript.new_comparison(@name, '>=', value)
      filter_js
    end

    def <=(value)
      filter_js = FilterJavascript.new_comparison(@name, '<=', value)
      filter_js
    end

    def javascript(js)
      filter_js = FilterJavascript.new(@name, js)
      filter_js
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
  
  class RecFilter < FilterDimension

    def initialize(dimension, bounds)
      @dimension = dimension
      @bounds = bounds
    end 

    def to_hash
      {
      :type => "spatial",
      :dimension => @dimension,
      :bound =>{
        :type => "rectangular",
        :minCoords => @bounds.first,
        :maxCoords => @bounds.last
        }
      }
    end
  end

  class CircFilter < FilterDimension

    def initialize(dimension, bounds)
      @dimension = dimension
      @bounds = bounds
    end 

    def to_hash
      {
      :type => "spatial",
      :dimension => @dimension,
      :bound =>{
        :type => "radius",
        :coords => @bounds.first,
        :radius => @bounds.last
        }
      }
    end
  end

  class FilterJavascript < FilterDimension
    def initialize(dimension, expression)
      @dimension = dimension
      @expression = expression
    end

    def self.new_comparison(dimension, operator, value)
      self.new(dimension, "#{dimension} #{operator} #{value.is_a?(String) ? "'#{value}'" : value}")
    end

    def to_hash
      {
        :type => 'javascript',
        :dimension => @dimension,
        :function => "function(#{@dimension}) { return(#{@expression}); }"
      }
    end
  end
end