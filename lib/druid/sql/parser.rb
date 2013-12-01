require 'parslet'

module Druid
  module SQL
    class Parser < Parslet::Parser
      root(:query)
      rule(:query) {
        select_stmt >>
        where_stmt.maybe >>
        groupby_stmt.maybe
      }

      rule(:select_stmt) {
        select >>
        aliased_expression_list.as(:expression) >>
        from >>
        identifier.as(:source)
      }

      rule(:aliased_expression_list) {
        aliased_expression >> (comma >> aliased_expression).repeat
      }

      rule(:aliased_expression) {
        expression.as(:expression) >>
        as >>
        identifier.as(:name)
      }

      rule(:expression) {
        add_expression
      }

      rule(:add_expression) {
        (
          multiply_expression.as(:left) >>
          (plus | minus).as(:op) >>
          multiply_expression.as(:right)
        ).as(:arithmetic) |
        multiply_expression
      }

      rule(:multiply_expression) {
        (
          unary_expression.as(:left) >>
          (star | div).as(:op) >>
          unary_expression.as(:right)
        ).as(:arithmetic) |
        unary_expression
      }

      rule(:unary_expression) {
        (minus >> unary_expression) |
        (plus >> unary_expression) |
        primary_expression
      }

      rule(:primary_expression) {
        constant.as(:constant) |
        aggregate.as(:aggregate) |
        lparen >> expression >> rparen
      }

      rule(:constant) {
        number
      }

      rule(:aggregate) {
        (
          (long_sum | double_sum | min | max).as(:type) >>
          lparen >> identifier.as(:field) >> rparen
        ) | (
          count.as(:type) >>
          lparen >> star.as(:field) >> rparen
        )
      }

      rule(:where_stmt) {
        where >>
        time_dim_filter
      }

      rule(:time_dim_filter) {
        (dim_filter >> and_op).maybe >>
        (
          time_filter_list >> and_op >> dim_filter |
          time_filter_list |
          dim_filter
        ).maybe
      }

      rule(:dim_filter) {
        or_dim_filter.as(:filter)
      }

      rule(:or_dim_filter) {
        (
          and_dim_filter.as(:left) >>
          or_op.as(:op) >>
          and_dim_filter.as(:right)
        ).as(:or) |
        and_dim_filter
      }

      rule(:and_dim_filter) {
        (
          primary_dim_filter.as(:left) >>
          and_op.as(:op) >>
          primary_dim_filter.as(:right)
        ).as(:and) |
        primary_dim_filter
      }

      rule(:primary_dim_filter) {
        selector_dim_filter |
        in_list_dim_filter |
        not_op >> dim_filter |
        lparen >> dim_filter >> rparen
      }

      rule(:selector_dim_filter) {
        identifier.as(:dimension) >>
        (eq_op | neq_op | match_op).as(:op) >>
        string.as(:value)
      }

      rule(:in_list_dim_filter) {
        identifier.as(:dimension) >>
        in_op >>
        lparen >>
        dimension_list >>
        rparen
      }

      rule(:dimension_list) {
        dimension >> (comma >> dimension).repeat
      }

      rule(:dimension) {
        string
      }

      rule(:time_filter_list) {
        (
          time_filter >> (str('and') >> time_filter).repeat
        ).as(:intervals)
      }

      rule(:time_filter) {
        (
          space? >>
          str('timestamp') >> space? >>
          between >>
          timestamp.as(:start) >> space? >>
          str('and') >> space? >>
          timestamp.as(:stop) >> space?
        ).as(:interval)
      }

      rule(:timestamp) {
        string
      }

      rule(:groupby_stmt) {
        group >> by >>
        groupby_expression_list.as(:groups)
      }

      rule(:groupby_expression_list) {
        groupby_expression >> (comma >> groupby_expression).repeat
      }

      rule(:groupby_expression) {
        granularity_fn |
        identifier.as(:dimension)
      }

      rule(:granularity_fn) {
        granularity >>
        lparen >>
        identifier.as(:granularity) >>
        rparen
      }

      # characters
      rule(:space) { match('\s').repeat(1) }
      rule(:space?) { space.maybe }

      rule(:lparen) { space? >> str('(') >> space? }
      rule(:rparen) { space? >> str(')') >> space? }
      rule(:comma)  { space? >> str(',') >> space? }

      rule(:letter) { match['a-zA-Z'] }
      rule(:string) {
        str('"') >> (
          str('\\') >> any | str('"').absent? >> any
        ).repeat.as(:string) >> str('"')
      }

      rule(:digit) { match['0-9'] }
      rule(:number) { (digit.repeat(1) >> (str('.') >> digit.repeat(1) >> exponent.maybe).maybe).as(:number) }
      rule(:exponent) { str('e') >> (plus | minus).maybe >> digit.repeat }

      rule(:identifier) { (letter >> (letter | digit | str('_')).repeat).as(:identifier) }

      # operators
      rule(:plus)     { space? >> str('+').as(:value)   >> space? }
      rule(:minus)    { space? >> str('-').as(:value)   >> space? }
      rule(:star)     { space? >> str('*').as(:value)   >> space? }
      rule(:div)      { space? >> str('/').as(:value)   >> space? }
      rule(:in_op)    { space? >> str('in').as(:value)  >> space }
      rule(:and_op)   { space? >> str('and').as(:value) >> space }
      rule(:or_op)    { space? >> str('or').as(:value)  >> space }
      rule(:not_op)   { space? >> str('!').as(:value)   >> space? }
      rule(:eq_op)    { space? >> str('=').as(:value)   >> space? }
      rule(:neq_op)   { space? >> str('!=').as(:value)  >> space? }
      rule(:match_op) { space? >> str('~').as(:value)   >> space? }

      # tokens
      rule(:select) { space? >> str('select') >> space }
      rule(:from) { space? >> str('from') >> space }
      rule(:as) { space? >> str('as') >> space }
      rule(:where) { space? >> str('where') >> space }
      rule(:group) { space? >> str('group') >> space }
      rule(:by) { space? >> str('by') >> space }
      rule(:granularity) { space? >> str('granularity') >> space? }
      rule(:long_sum) { space? >> str('longSum') >> space? }
      rule(:double_sum) { space? >> str('doubleSum') >> space? }
      rule(:min) { space? >> str('min') >> space? }
      rule(:max) { space? >> str('max') >> space? }
      rule(:count) { space? >> str('count') >> space? }
      rule(:between) { space? >> str('between') >> space }
    end
  end
end
