module Druid
  class Client
    TIMEOUT = 2 * 60 * 1000

    def initialize(zookeeper_uri, opts = nil)
      opts ||= {}

      if opts[:static_setup] && !opts[:fallback]
        @static = opts[:static_setup]
      else
        @backup = opts[:static_setup] if opts[:fallback]
        zookeeper_caching_management!(zookeeper_uri, opts)
      end
    end

    def send(query)
      uri = data_source_uri(query.source)
      raise "data source #{query.source} (currently) not available" unless uri

      req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
      req.body = query.to_json

      response = Net::HTTP.new(uri.host, uri.port).start do |http|
        http.read_timeout = TIMEOUT
        http.request(req)
      end

      if response.code == "200"
        JSON.parse(response.body).map{ |row| ResponseRow.new(row) }
      else
        raise "Request failed: #{response.code}: #{response.body}"
      end
    end

    def query(id, &block)
      uri = data_source_uri(id)
      raise "data source #{id} (currently) not available" unless uri
      query = Query.new(id, self)
      return query unless block

      send query
    end

    def zookeeper_caching_management!(zookeeper_uri, opts)
      @zk = ZooHandler.new(zookeeper_uri, opts)

      unless opts[:zk_keepalive]
        @cached_data_sources = @zk.data_sources unless @zk.nil?

        @zk.close!
      end
    end

    def ds
      @cached_data_sources || (@zk.data_sources unless @zk.nil?)
    end

    def data_sources
      (ds.nil? ? @static : ds).keys
    end

    def data_source_uri(source)
      uri = (ds.nil? ? @static : ds)[source]
      begin
        return URI(uri) if uri
      rescue
         return URI(@backup) if @backup
      end
    end

    def data_source(source)
      uri = data_source_uri(source)
      raise "data source #{source} (currently) not available" unless uri

      meta_path = "#{uri.path}datasources/#{source.split('/').last}"

      req = Net::HTTP::Get.new(meta_path)

      response = Net::HTTP.new(uri.host, uri.port).start do |http|
        http.read_timeout = TIMEOUT
        http.request(req)
      end

      if response.code == "200"
        meta = JSON.parse(response.body)
        meta.define_singleton_method(:dimensions) { self['dimensions'] }
        meta.define_singleton_method(:metrics) { self['metrics'] }
        meta
      else
        raise "Request failed: #{response.code}: #{response.body}"
      end
    end
  end
end
