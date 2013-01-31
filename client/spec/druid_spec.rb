$:.push File.expand_path("../lib", __FILE__)

require 'druid'

describe Druid::Query do

  it 'takes a datasource in the constructor' do
    query = Druid::Query.new('test')
    JSON.parse(query.to_json)['dataSource'].should == 'test'
  end

  it 'takes a query type' do
    query = Druid::Query.new('test')
    query.query_type('query_type')
    JSON.parse(query.to_json)['queryType'].should == 'query_type'
  end

  it 'sets query type by group' do
    query = Druid::Query.new('test')
    query.group()
    JSON.parse(query.to_json)['queryType'].should == 'groupBy'
  end

  it 'takes dimensions from group method' do
    query = Druid::Query.new('test')
    query.group(:a, :b, :c)
    JSON.parse(query.to_json)['dimensions'].should == ['a', 'b', 'c']
  end

  it 'builds aggregations on long_sum' do
    query = Druid::Query.new('test')
    query.long_sum(:a, :b, :c)
    JSON.parse(query.to_json)['aggregations'].should == [
      { 'type' => 'longSum', 'name' => 'a', 'fieldName' => 'a'},
      { 'type' => 'longSum', 'name' => 'b', 'fieldName' => 'b'},
      { 'type' => 'longSum', 'name' => 'c', 'fieldName' => 'c'}
    ]
  end

  it 'removes old long_sum properties from aggregations on calling long_sum again' do
    query = Druid::Query.new('test')
    query.long_sum(:a, :b, :c)
    query.double_sum(:x,:y)
    query.long_sum(:d, :e, :f)
    JSON.parse(query.to_json)['aggregations'].sort{|x,y| x['name'] <=> y['name']}.should == [
      { 'type' => 'longSum', 'name' => 'd', 'fieldName' => 'd'},
      { 'type' => 'longSum', 'name' => 'e', 'fieldName' => 'e'},
      { 'type' => 'longSum', 'name' => 'f', 'fieldName' => 'f'},
      { 'type' => 'doubleSum', 'name' => 'x', 'fieldName' => 'x'},
      { 'type' => 'doubleSum', 'name' => 'y', 'fieldName' => 'y'}
    ]
  end

  it 'must be chainable' do
    q = [Druid::Query.new('test')]
    q.push q[-1].query_type('a')
    q.push q[-1].data_source('b')
    q.push q[-1].group('c')
    q.push q[-1].long_sum('d')
    q.push q[-1].double_sum('e')
    q.push q[-1].filter{a.eq 1}
    q.push q[-1].interval("2013-01-26T00", "2020-01-26T00:15")
    q.push q[-1].granularity(:day)

    q.each do |instance|
      instance.should == q[0]
    end
  end

  it 'parses intervals from strings' do
    query = Druid::Query.new('test')
    query.interval('2013-01-26T0', '2020-01-26T00:15')
    JSON.parse(query.to_json)['intervals'].should == ['2013-01-26T00:00:00+00:00/2020-01-26T00:15:00+00:00']
  end

  it 'accepts Time objects for intervals' do
    query = Druid::Query.new('test')
    query.interval(a = Time.now, b = Time.now + 1)
    JSON.parse(query.to_json)['intervals'].should == ["#{a.iso8601}/#{b.iso8601}"]
  end

  it 'takes a granularity from string' do
    query = Druid::Query.new('test')
    query.granularity('all')
    JSON.parse(query.to_json)['granularity'].should == 'all'
  end

end
