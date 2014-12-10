module Druid
  class Filter
    (instance_methods + private_instance_methods).each do |method|
      unless method.to_s =~ /^(__|instance_eval|instance_exec|initialize|object_id|raise|puts|inspect|send)/ || method.to_s =~ /\?/
        undef_method method
      end
    end

    def self.from_hash(hash, type = :in)
      unless [:in, :nin].include?(type)
        raise ArgumentError.new("#{type} is not a valid filter type")
      end

      last_filter = nil
      hash.each do |dimension, values|
        filter = FilterDimension.new(dimension).send(type, values)
        last_filter = last_filter ? last_filter.&(filter) : filter
      end

      last_filter
    end

    def self.from_block(&block)
      filter = self.new.instance_exec(&block)

      unless filter.is_a?(FilterParameter)
        raise ArgumentError.new("Not a valid filter block")
      end

      filter
    end

    def method_missing(method_id, *args)
      FilterDimension.new(method_id)
    end
  end

  class FilterParameter
    include Serializable
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
      filter_multiple(values, 'or', :eq)
    end

    def nin(*args)
      values = args.flatten
      filter_multiple(values, 'and', :neq)
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

    private

    def filter_multiple(values, operator, method)
      raise 'Values cannot be empty' if values.empty?
      return self.send(method, values[0]) if values.length == 1

      filter = FilterOperator.new(operator, true)
      values.each do |value|
        raise 'Value cannot be a parameter' if value.is_a?(FilterParameter)
        filter.add(FilterDimension.new(@name).send(method, value))
      end
      filter
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
