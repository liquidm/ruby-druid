$:.push File.expand_path("../../lib", __FILE__)

require 'druid'

describe Druid::Query do

  before :each do
    @query = Druid::Query.new('test')
  end

  it 'takes a datasource in the constructor' do
    query = Druid::Query.new('test')
    JSON.parse(query.to_json)['dataSource'].should == 'test'
  end

  it 'takes a query type' do
    @query.query_type('query_type')
    JSON.parse(@query.to_json)['queryType'].should == 'query_type'
  end

  it 'sets query type by group' do
    @query.group()
    JSON.parse(@query.to_json)['queryType'].should == 'groupBy'
  end

  it 'takes dimensions from group method' do
    @query.group(:a, :b, :c)
    JSON.parse(@query.to_json)['dimensions'].should == ['a', 'b', 'c']
  end

  it 'builds aggregations on long_sum' do
    @query.long_sum(:a, :b, :c)
    JSON.parse(@query.to_json)['aggregations'].should == [
      { 'type' => 'longSum', 'name' => 'a', 'fieldName' => 'a'},
      { 'type' => 'longSum', 'name' => 'b', 'fieldName' => 'b'},
      { 'type' => 'longSum', 'name' => 'c', 'fieldName' => 'c'}
    ]
  end

  it 'removes old long_sum properties from aggregations on calling long_sum again' do
    @query.long_sum(:a, :b, :c)
    @query.double_sum(:x,:y)
    @query.long_sum(:d, :e, :f)
    JSON.parse(@query.to_json)['aggregations'].sort{|x,y| x['name'] <=> y['name']}.should == [
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
    @query.interval('2013-01-26T0', '2020-01-26T00:15')
    JSON.parse(@query.to_json)['intervals'].should == ['2013-01-26T00:00:00+00:00/2020-01-26T00:15:00+00:00']
  end

  it 'accepts Time objects for intervals' do
    @query.interval(a = Time.now, b = Time.now + 1)
    JSON.parse(@query.to_json)['intervals'].should == ["#{a.iso8601}/#{b.iso8601}"]
  end

  it 'takes a granularity from string' do
    @query.granularity('all')
    JSON.parse(@query.to_json)['granularity'].should == 'all'
  end

  it 'creates an equals filter' do
    @query.filter{a.eq 1}
    JSON.parse(@query.to_json)['filter'].should == {"type"=>"selector", "dimension"=>"a", "value"=>1}
  end

  it 'creates an equals filter with ==' do
    @query.filter{a == 1}
    JSON.parse(@query.to_json)['filter'].should == {"type"=>"selector", "dimension"=>"a", "value"=>1}
  end


  it 'creates a not filter' do
    @query.filter{!a.eq 1}
    JSON.parse(@query.to_json)['filter'].should ==  {"field" =>
      {"type"=>"selector", "dimension"=>"a", "value"=>1},
    "type" => "not"}
  end

  it 'creates a not filter with neq' do
    @query.filter{a.neq 1}
    JSON.parse(@query.to_json)['filter'].should ==  {"field" =>
      {"type"=>"selector", "dimension"=>"a", "value"=>1},
    "type" => "not"}
  end

  it 'creates a not filter with !=' do
    @query.filter{a != 1}
    JSON.parse(@query.to_json)['filter'].should ==  {"field" =>
      {"type"=>"selector", "dimension"=>"a", "value"=>1},
    "type" => "not"}
  end


  it 'creates an and filter' do
    @query.filter{a.neq(1) & b.eq(2) & c.eq('foo')}
    JSON.parse(@query.to_json)['filter'].should ==  {"fields" => [
      {"type"=>"not", "field"=>{"type"=>"selector", "dimension"=>"a", "value"=>1}},
      {"type"=>"selector", "dimension"=>"b", "value"=>2},
      {"type"=>"selector", "dimension"=>"c", "value"=>"foo"}
    ],
  "type" => "and"}
end

  it 'creates an or filter' do
    @query.filter{a.neq(1) | b.eq(2) | c.eq('foo')}
    JSON.parse(@query.to_json)['filter'].should ==  {"fields" => [
      {"type"=>"not", "field"=> {"type"=>"selector", "dimension"=>"a", "value"=>1}},
      {"type"=>"selector", "dimension"=>"b", "value"=>2},
      {"type"=>"selector", "dimension"=>"c", "value"=>"foo"}
    ],
  "type" => "or"}
  end

  it 'chains filters' do
    @query.filter{a.eq(1)}.filter{b.eq(2)}
    JSON.parse(@query.to_json)['filter'].should ==  {"fields" => [
      {"type"=>"selector", "dimension"=>"a", "value"=>1},
      {"type"=>"selector", "dimension"=>"b", "value"=>2}
    ],
    "type" => "and"}
  end

  it 'creates filter from hash' do
    @query.filter a:1, b:2
    JSON.parse(@query.to_json)['filter'].should ==  {"fields" => [
      {"type"=>"selector", "dimension"=>"a", "value"=>1},
      {"type"=>"selector", "dimension"=>"b", "value"=>2}
    ],
    "type" => "and"}

  end

  it 'creates an in statement with or filter' do
    @query.filter{a.in [1,2,3]}
    JSON.parse(@query.to_json)['filter'].should ==  {"fields" => [
      {"type"=>"selector", "dimension"=>"a", "value"=>1},
      {"type"=>"selector", "dimension"=>"a", "value"=>2},
      {"type"=>"selector", "dimension"=>"a", "value"=>3}
    ],
    "type" => "or"}
  end

  it 'can chain two in statements' do
    @query.filter{a.in([1,2,3]) & b.in([1,2,3])}
    JSON.parse(@query.to_json)['filter'].should == {"type"=>"and", "fields"=>[
      {"type"=>"or", "fields"=>[
        {"type"=>"selector", "dimension"=>"a", "value"=>1},
        {"type"=>"selector", "dimension"=>"a", "value"=>2},
        {"type"=>"selector", "dimension"=>"a", "value"=>3}
      ]},
      {"type"=>"or", "fields"=>[
        {"type"=>"selector", "dimension"=>"b", "value"=>1},
        {"type"=>"selector", "dimension"=>"b", "value"=>2},
        {"type"=>"selector", "dimension"=>"b", "value"=>3}
      ]}
    ]}
  end

  it 'does not accept in with empty array' do
    expect { @query.filter{a.in []} }.to raise_error "Must provide non-empty array in in()"
  end

  it 'does raise on invalid filter statement' do
    expect { @query.filter{:a} }.to raise_error 'Not a valid filter'
  end

  it 'raises if no value is passed to a filter operator' do
    expect { @query.filter{a.eq a}.to_json}.to raise_error 'no value assigned'
  end

  it 'raises wrong number of arguments if  filter operator is called without param' do
    expect { @query.filter{a.eq}.to_json}.to raise_error 'wrong number of arguments (0 for 1)'
  end

end
