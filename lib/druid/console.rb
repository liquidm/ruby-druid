require 'active_support/time'
require 'ap'
require 'forwardable'
require 'irb'
require 'ripl'
require 'terminal-table'

require 'druid'
require 'druid/sql'

Ripl::Shell.class_eval do
  def format_query_result(query)
    result = $client.submit(query)
    return nil if result.empty?
    columns = result.last.keys
    Terminal::Table.new({
      headings: columns,
      rows: result.map { |row|
        columns.map { |column|
          row[column]
        }
      }
    })
  end

  def format_result(result)
    if result.is_a?(Druid::Query)
      puts format_query_result(result.properties)
    elsif result.is_a?(Druid::SQL::GroupByQuery)
      puts format_query_result(result.query)
    else
      ap(result)
    end
  end
end

module Druid
  class Console

    extend Forwardable

    def initialize(uri, source, options)
      @uri, @source, @options = uri, source, options
      $client = client
      Ripl.start(binding: binding)
    end

    def client
      @client ||= Druid::Client.new(@uri, @options)
      @source ||= @client.data_sources[0]
      @client
    end

    def source
      client.data_source(@source)
    end

    def dimensions
      source.dimensions
    end

    def metrics
      source.metrics
    end

    def query
      client.query(@source)
    end

    def sql(query)
      Druid::SQL.parse(query)
    rescue Parslet::ParseFailed => failure
      puts failure.cause.ascii_tree
    end

    def_delegators :query, :group_by, :sum, :long_sum, :double_sum, :postagg, :interval, :granularity, :filter, :time_series
  end
end
