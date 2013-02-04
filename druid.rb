require './lib/query.rb'
require './lib/zkhandler.rb'
require 'json'
require 'rest_client'

module Druid
  class Client
    def initialize(zookeeper_uri, opts = {})
      @zk = ZooHandler.new zookeeper_uri, opts
    end

    def data_sources
      @zk.data_sources
    end

    def query(id, &block)
      uri = @zk.data_sources[id]
      throw "data source #{id} (currently) not available" unless uri

      service, data_source = id.split '/'
      query = Query.new(data_source)
      query.instance_exec(&block)

      response = RestClient.post uri, query.to_json, :content_type => :json, :accept => :json

      throw response.to_str if response.code != 200

      JSON.parse response.to_str
    end
  end
end
