require './lib/zoo_handler.rb'
require './lib/query.rb'
require './lib/response_row.rb'
require 'json'
require 'net/http'

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

      data_source = id.split('/').last
      
      query = Query.new(data_source)

      uri = URI(@zk.data_sources[id])
      req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
      req.body = query.instance_exec(&block).to_json

      response = Net::HTTP.new(uri.host, uri.port).start do |http| 
        http.read_timeout = (2 * 60 * 1000)
        http.request(req)
      end

      if response.code == "200"
        JSON.parse(response.body).map{ |row| ResponseRow.new(row) }
      else
        raise "Request failed: #{response.code}: #{response.body} "
      end
    end
  end
end
