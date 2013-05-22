require 'zk'
require 'json'
require 'rest_client'

module Druid

  class ZooHandler
    def initialize(uri, opts = {})
      @zk = ZK.new uri, :chroot => :check
      @registry = Hash.new {|hash,key| hash[key] = Array.new }
      @discovery_path = opts[:discovery_path] || '/discoveryPath'
      @watched_services = Hash.new

      init_zookeeper
    end

    def init_zookeeper
      @zk.on_expired_session do
        init_zookeeper
      end

      @zk.register(@discovery_path, :only => :child) do |event|
        check_services
      end

      check_services
    end

    def check_services
      zk_services = @zk.children @discovery_path, :watch => true

      #remove deprecated services
      (services - zk_services).each do |old_service|
        @registry.delete old_service
        if @watched_services.include? old_service
          @watched_services.delete(old_service).unregister
        end
      end

      zk_services.each do |service|
        check_service service unless @watched_services.include? service
      end
    end

    def check_service(service)
      unless @watched_services.include? service
        watchPath = "#{@discovery_path}/#{service}"
        @watched_services[service] = @zk.register(watchPath, :only => :child) do |event|
          old_handler = @watched_services.delete(service)
          if old_handler
            old_handler.unregister
          end
          check_service service
        end
        
        known = @registry[service].map{ |node| node[:name] } rescue []
        live = @zk.children(watchPath, :watch => true)

        # copy the unchanged entries
        new_list = @registry[service].select{ |node| live.include? node[:name] } rescue []

        # verify the new entries to be living brokers
        (live - known).each do |name|
          info = @zk.get "#{watchPath}/#{name}"
          node = JSON.parse(info[0])
          uri =  "http://#{node['address']}:#{node['port']}/druid/v2/"

          begin
            check_uri = "#{uri}datasources/"

            check = RestClient::Request.execute({
              :method => :get,
              :url => check_uri,
              :timeout => 5,
              :open_timeout => 5
            })

            if check.code == 200
              new_list.push({
                :name => name,
                :uri => uri,
                :data_sources => JSON.parse(check.to_str)
              })
            else
            end
          rescue
          end
        end

        if !new_list.empty?
          # poor mans load balancing
          @registry[service] = new_list.shuffle
        else
          # don't show services w/o active brokers
          @registry.delete service
        end
      end
    end

    def services
      @registry.keys
    end

    def data_sources
      result = Hash.new { |hash, key| hash[key] = [] }

      @registry.each do |service, brokers|
        brokers.each do |broker|
          broker[:data_sources].each do |data_source|
            result["#{service}/#{data_source}"] << broker[:uri]
          end
        end
      end
      result.each do |source, uris|
        result[source] = uris.sample if uris.respond_to?(:sample)
      end

      result
    end

    def to_s
      @registry.to_s
    end
  end
end
