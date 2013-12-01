require 'druid/sql/parser'
require 'druid/sql/transform'

module Druid
  module SQL
    def self.parse(query)
      @parser ||= Druid::SQL::Parser.new
      @transform ||= Druid::SQL::Transform.new
      tree = @parser.parse(query)
      tree = @transform.apply(tree)
      tree = @transform.apply(tree)
      GroupByQuery.new(tree)
    end
  end
end
