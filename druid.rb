require './lib/zkhandler.rb'
require './lib/query.rb'
require './lib/responserow.rb'
require 'json'
require 'rest_client'

module Druid
  class Client
    def initialize(zookeeper_uri, opts = {})
      @zk = ZooHandler.new zookeeper_uri, opts
    end

    def data_sources
      @zk.data_sources.keys
    end

    def query(id, &block)
      uri = @zk.data_sources[id]
      throw "data source #{id} (currently) not available" unless uri

      service, data_source = id.split '/'
      query = Query.new(data_source)
      query.instance_exec(&block)

      response = RestClient::Request.execute({
        :method => :post,
        :url => uri,
        :timeout => (2 * 60 * 1000),
        :payload => query.to_json,
        :headers => {
          :content_type => :json,
          :accept => :json
        }
      })

      throw response.to_str if response.code != 200

      JSON.parse(response.to_str).map{ |row| ResponseRow.new(row) }
    end
  end
end
