module Druid
  class Client

    attr_accessor :uri

    def initialize(zookeeper_uri, opts = {})
      @zk = ZooHandler.new zookeeper_uri, opts
    end

    def send(query)
      uri = query.client.uri
      req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
      req.body = query.to_json#.instance_exec(&block).to_json

      response = Net::HTTP.new(uri.host, uri.port).start do |http| 
        http.read_timeout = (2 * 60 * 1000)
        http.request(req)
      end

      if response.code == "200"
        JSON.parse(response.body).map{ |row| ResponseRow.new(row) }
      else
        raise "Request failed: #{response.code}: #{response.body}"
      end
    end

    def query(id, &block)
      uri = @zk.data_sources[id]
      raise "data source #{id} (currently) not available" unless uri
      @uri = URI(uri)
      data_source = id.split('/').last
      
      query = Query.new(data_source, self)
      return query unless block      

      send query
    end
  end
end
