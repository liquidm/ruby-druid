require 'active_support/time'
require 'ap'
require 'forwardable'
require 'irb'
require 'ripl'
require 'terminal-table'

require 'druid'

Ripl::Shell.class_eval do
  def format_query_result(result, query)

    include_timestamp = query.properties[:granularity] != 'all'

    keys = result.empty? ? [] : result.last.keys

    Terminal::Table.new({
      headings: (include_timestamp ? ["timestamp"] : []) + keys,
      rows: result.map { |row| (include_timestamp ? [row.timestamp] : []) + row.values }
    })
  end

  def format_result(result)
    if result.is_a?(Druid::Query)
      puts format_query_result(result.send, result)
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

    def_delegators :query, :group_by, :sum, :long_sum, :postagg, :interval, :granularity, :filter, :time_series
  end
end
