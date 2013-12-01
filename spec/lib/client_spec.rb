require 'spec_helper'

describe Druid::Client do

  it 'calls zookeeper on intialize' do
    Druid::ZooHandler.should_receive(:new)
    Druid::Client.new('test_uri', zk_keepalive: true)
  end

  it 'creates a query' do
    Druid::ZooHandler.stub(:new).and_return(double(Druid::ZooHandler, :data_sources => {'test/test' => 'http://www.example.com'}, :close! => true))
    Druid::Client.new('test_uri', zk_keepalive: true).query('test/test').should be_a Druid::Query
  end

  it 'sends query if block is given' do
    Druid::ZooHandler.stub(:new).and_return(double(Druid::ZooHandler, :data_sources => {'test/test' => 'http://www.example.com'}, :close! => true))
    client = Druid::Client.new('test_uri', zk_keepalive: true)
    client.should_receive(:send)
    client.query('test/test') do
      group(:group1)
    end
  end

  it 'parses response on 200' do
    stub_request(:post, "http://www.example.com/druid/v2").
      with(:body => "{\"dataSource\":\"test\",\"granularity\":\"all\",\"intervals\":[\"2013-04-04T00:00:00+00:00/2013-04-04T00:00:00+00:00\"]}",
      :headers => {'Accept'=>'*/*', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => "[]", :headers => {})
    Druid::ZooHandler.stub(:new).and_return(double(Druid::ZooHandler, :data_sources => {'test/test' => 'http://www.example.com/druid/v2'}, :close! => true))
    client = Druid::Client.new('test_uri', zk_keepalive: true)
    JSON.should_receive(:parse).and_return([])
    client.send(client.query('test/test').interval("2013-04-04", "2013-04-04"))
  end

  it 'raises on request failure' do
    stub_request(:post, "http://www.example.com/druid/v2").
      with(:body => "{\"dataSource\":\"test\",\"granularity\":\"all\",\"intervals\":[\"2013-04-04T00:00:00+00:00/2013-04-04T00:00:00+00:00\"]}",
      :headers => {'Accept'=>'*/*', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
      to_return(:status => 666, :body => "Strange server error", :headers => {})
    Druid::ZooHandler.stub(:new).and_return(double(Druid::ZooHandler, :data_sources => {'test/test' => 'http://www.example.com/druid/v2'}, :close! => true))
    client = Druid::Client.new('test_uri', zk_keepalive: true)
    expect { client.send(client.query('test/test').interval("2013-04-04", "2013-04-04")) }.to raise_error(RuntimeError, /Request failed: 666: Strange server error/)
  end

  it 'should have a static setup' do
    client = Druid::Client.new('test_uri', :static_setup => {'madvertise/mock' => 'mock_uri'})
    client.data_sources.should == ['madvertise/mock']
    client.data_source_uri('madvertise/mock').should == URI('mock_uri')
  end

  it 'should report dimensions of a data source correctly' do
    stub_request(:get, "http://www.example.com/druid/v2/datasources/mock").
      with(:headers =>{'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => '{"dimensions":["d1","d2","d3"],"metrics":["m1", "m2"]}')

    client = Druid::Client.new('test_uri', :static_setup => {'madvertise/mock' => 'http://www.example.com/druid/v2/'})
    client.data_source('madvertise/mock').dimensions.should == ["d1","d2","d3"]
  end

  it 'should report metrics of a data source correctly' do
    stub_request(:get, "http://www.example.com/druid/v2/datasources/mock").
      with(:headers =>{'Accept'=>'*/*', 'User-Agent'=>'Ruby'}).
      to_return(:status => 200, :body => '{"dimensions":["d1","d2","d3"],"metrics":["m1", "m2"]}')

    client = Druid::Client.new('test_uri', :static_setup => {'madvertise/mock' => 'http://www.example.com/druid/v2/'})
    client.data_source('madvertise/mock').metrics.should == ["m1","m2"]
  end

end
