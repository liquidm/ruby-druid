$:.push File.expand_path("../../lib", __FILE__)

require 'zkhandler'

module ZK
  def self.new(uri, opts = {})
    Mock.new uri, opts
  end

  class Mock
    include RSpec::Matchers

    def initialize(uri, opts)
      uri.should == 'test-uri'
      opts.should == { :chroot => :check }
      @registrations = {}
    end

    def register(path, opts, &block)
      opts.should == { :only => :child }
      @registrations[path].should == nil
      @registrations[path] = block
    end

    def children(path, opts)
      @registrations[path].should be_a(Proc)

      case path
      when '/disco'
        ['a', 'b']
      when '/disco/a'
        ['b1', 'm1']
      when '/disco/b'
        ['b2', 'm2']
      else
        throw "no mock code for #{path}"
      end
    end

    def get(path)
      case path
      when '/disco/a/b1'
        [{
          :address => 'b1_address',
          :port => 80
        }.to_json]
      when '/disco/a/m1'
        [{
          :address => 'm1_address',
          :port => 81
        }.to_json]
      when '/disco/b/b2'
        [{
          :address => 'b2_address',
          :port => 90
        }.to_json]
      when '/disco/b/m2'
        [{
          :address => 'm2_address',
          :port => 85
        }.to_json]
      else
        throw "no mock code for #{path}"
      end
    end
  end
end

class RestClientResponseMock
  def initialize(code, value)
    @code = code
    @value = value
  end

  def code
    @code
  end

  def to_str
    @value.to_str
  end
end

describe Druid::ZooHandler do
  it 'reports services and data sources correctly' do
    calls = []
    RestClient::Request.stub(:execute) do |opts|
      uri_match = opts[:url].match /^http:\/\/(.+)_address:(.+)\/druid\/v2\/datasources\/$/

      host = uri_match[1]
      port = uri_match[2].to_i

      calls.push [host, port]

      case host
      when 'b1'
        RestClientResponseMock.new(200, ['s1','s2'].to_json)
      when 'b2'
        RestClientResponseMock.new(200, ['s3','s4'].to_json)
      else
        RestClientResponseMock.new(404, nil)
      end
    end

    zk = Druid::ZooHandler.new 'test-uri', :discovery_path => '/disco'

    calls.should == [
      ['b1', 80],
      ['m1', 81],
      ['b2', 90],
      ['m2', 85]
    ]

    zk.services.should == ['a', 'b']

    zk.data_sources.should == {
      'a/s1' => 'http://b1_address:80/druid/v2/',
      'a/s2' => 'http://b1_address:80/druid/v2/',
      'b/s3' => 'http://b2_address:90/druid/v2/',
      'b/s4' => 'http://b2_address:90/druid/v2/'
    }
  end
end
