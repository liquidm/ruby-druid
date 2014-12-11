require 'druid/base_query'

module Druid
  class SearchQuery < BaseQuery

    def initialize(source, client = nil)
      super
      @query_type = :search
    end

    def contains(*values)
      flat_values = values.flatten

      if flat_values.length > 1
        @query = {
          type: :fragment,
          values: flat_values
        }
      else
        @query = {
          type: :insensitive_contains,
          value: flat_values.first,
        }
      end

      self
    end

    def sort(type)
      @sort = { type: type.to_s }
      self
    end

    def to_hash
      hash = super.merge({
        query: @query,
        searchDimensions: @dimensions,
        sort: @sort,
      })

      hash.delete(:dimensions)

      hash
    end

  end
end
