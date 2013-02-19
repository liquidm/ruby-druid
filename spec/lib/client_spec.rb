require 'spec_helper'

describe Druid::Client do

	it 'calls zookeeper on intialize' do
		Druid::ZooHandler.should_receive(:new)
		Druid::Client.new('test_uri')
	end

	it 'creates a query' do
		Druid::ZooHandler.stub!(:new).and_return(mock(Druid::ZooHandler, :data_sources => {'test/test' => 'http://www.example.com'}))
		Druid::Client.new('test_uri').query('test/test').should be_a Druid::Query
	end

	it 'sends query if block is given' do
		Druid::ZooHandler.stub!(:new).and_return(mock(Druid::ZooHandler, :data_sources => {'test/test' => 'http://www.example.com'}))
		client = Druid::Client.new('test_uri')
		client.should_receive(:send)
		client.query('test/test') do
			group(:group1)
		end
	end

	it 'parses response on 200' do
		stub_request(:post, "http://www.example.com/druid/v2").
			with(:body => "{\"dataSource\":\"test\"}",
			:headers => {'Accept'=>'*/*', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
			to_return(:status => 200, :body => "[]", :headers => {})
		Druid::ZooHandler.stub!(:new).and_return(mock(Druid::ZooHandler, :data_sources => {'test/test' => 'http://www.example.com/druid/v2'}))
		client = Druid::Client.new('test_uri')
		JSON.should_receive(:parse).and_return([])
		client.send(client.query('test/test'))
	end

	it 'raises on request failure' do
		stub_request(:post, "http://www.example.com/druid/v2").
			with(:body => "{\"dataSource\":\"test\"}",
			:headers => {'Accept'=>'*/*', 'Content-Type'=>'application/json', 'User-Agent'=>'Ruby'}).
			to_return(:status => 666, :body => "Strange server error", :headers => {})
		Druid::ZooHandler.stub!(:new).and_return(mock(Druid::ZooHandler, :data_sources => {'test/test' => 'http://www.example.com/druid/v2'}))
		client = Druid::Client.new('test_uri')
		expect { client.send(client.query('test/test')) }.to raise_error(RuntimeError, /Request failed: 666: Strange server error/)
	end

	it 'should have a static setup' do
		client = Druid::Client.new('test_uri', :static_setup => {'madvertise/mock' => 'mock_uri'})
		client.data_sources.should == ['madvertise/mock']
		client.data_source_uri('madvertise/mock').should == URI('mock_uri')
	end

end