require 'active_support/time'
require 'ap'
require 'forwardable'
require 'irb'
require 'ripl'
require 'terminal-table'

require 'druid'

Ripl::Shell.class_eval do
  def format_query_result(result)
    Terminal::Table.new({
      headings: result.last.keys,
      rows: result.map(&:values),
    })
  end

  def format_result(result)
    if result.is_a?(Druid::Query)
      puts format_query_result(result.send)
    else
      ap(result)
    end
  end
end

module Druid
  class Console

    extend Forwardable

    def initialize(uri, source)
      @uri, @source = uri, source
      Ripl.start(binding: binding)
    end

    def client
      @client ||= Druid::Client.new(@uri)
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

    def_delegators :query, :group_by, :long_sum, :postagg, :interval, :granularity, :filter
  end
end
