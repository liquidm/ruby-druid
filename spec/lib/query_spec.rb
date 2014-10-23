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

  it 'sets query type by group_by' do
    @query.group_by()
    JSON.parse(@query.to_json)['queryType'].should == 'groupBy'
  end

  it 'sets query type to timeseries' do
    @query.time_series()
    JSON.parse(@query.to_json)['queryType'].should == 'timeseries'
  end

  it 'takes dimensions from group_by method' do
    @query.group_by(:a, :b, :c)
    JSON.parse(@query.to_json)['dimensions'].should == ['a', 'b', 'c']
  end

  it 'takes dimension, metric and threshold from topn method' do
    @query.topn(:a, :b, 25)
    result = JSON.parse(@query.to_json)
    result['dimension'].should == 'a'
    result['metric'].should == 'b'
    result['threshold'].should == 25
  end

  describe '#postagg' do
    it 'build a post aggregation with a constant right' do
      @query.postagg{(a + 1).as ctr }

      JSON.parse(@query.to_json)['postAggregations'].should == [{"type"=>"arithmetic",
        "fn"=>"+",
        "fields"=>
        [{"type"=>"fieldAccess", "name"=>"a", "fieldName"=>"a"},
         {"type"=>"constant", "value"=>1}],
        "name"=>"ctr"}]
    end

    it 'build a + post aggregation' do
      @query.postagg{(a + b).as ctr }
      JSON.parse(@query.to_json)['postAggregations'].should == [{"type"=>"arithmetic",
        "fn"=>"+",
        "fields"=>
        [{"type"=>"fieldAccess","name"=>"a", "fieldName"=>"a"},
        {"type"=>"fieldAccess", "name"=>"b", "fieldName"=>"b"}],
        "name"=>"ctr"}]
    end

    it 'build a - post aggregation' do
      @query.postagg{(a - b).as ctr }
      JSON.parse(@query.to_json)['postAggregations'].should == [{"type"=>"arithmetic",
        "fn"=>"-",
        "fields"=>
        [{"type"=>"fieldAccess", "name"=>"a", "fieldName"=>"a"},
        {"type"=>"fieldAccess", "name"=>"b", "fieldName"=>"b"}],
        "name"=>"ctr"}]
    end

    it 'build a * post aggregation' do
      @query.postagg{(a * b).as ctr }
      JSON.parse(@query.to_json)['postAggregations'].should == [{"type"=>"arithmetic",
        "fn"=>"*",
        "fields"=>
        [{"type"=>"fieldAccess", "name"=>"a", "fieldName"=>"a"},
        {"type"=>"fieldAccess", "name"=>"b", "fieldName"=>"b"}],
        "name"=>"ctr"}]
    end

    it 'build a / post aggregation' do
      @query.postagg{(a / b).as ctr }
      JSON.parse(@query.to_json)['postAggregations'].should == [{"type"=>"arithmetic",
        "fn"=>"/",
        "fields"=>
        [{"type"=>"fieldAccess", "name"=>"a", "fieldName"=>"a"},
        {"type"=>"fieldAccess", "name"=>"b", "fieldName"=>"b"}],
      "name"=>"ctr"}]
    end

    it 'build a complex post aggregation' do
      @query.postagg{((a / b) * 1000).as ctr }
      JSON.parse(@query.to_json)['postAggregations'].should == [{"type"=>"arithmetic",
        "fn"=>"*",
        "fields"=>
        [{"type"=>"arithmetic", "fn"=>"/", "fields"=>
          [{"type"=>"fieldAccess", "name"=>"a", "fieldName"=>"a"},
           {"type"=>"fieldAccess", "name"=>"b", "fieldName"=>"b"}]},
        {"type"=>"constant", "value"=>1000}],
      "name"=>"ctr"}]
    end

    it 'adds fields required by the postagg operation to longsum' do
      @query.postagg{ (a/b).as c }
      JSON.parse(@query.to_json)['aggregations'].should == [
        {"type"=>"longSum", "name"=>"a", "fieldName"=>"a"},
        {"type"=>"longSum", "name"=>"b", "fieldName"=>"b"}
      ]
    end

    it 'chains aggregations' do
      @query.postagg{(a / b).as ctr }.postagg{(b / a).as rtc }

      JSON.parse(@query.to_json)['postAggregations'].should == [{"type"=>"arithmetic",
        "fn"=>"/",
        "fields"=>
        [{"type"=>"fieldAccess", "name"=>"a", "fieldName"=>"a"},
        {"type"=>"fieldAccess", "name"=>"b", "fieldName"=>"b"}],
      "name"=>"ctr"},
      {"type"=>"arithmetic",
        "fn"=>"/",
        "fields"=>
        [{"type"=>"fieldAccess", "name"=>"b", "fieldName"=>"b"},
        {"type"=>"fieldAccess", "name"=>"a", "fieldName"=>"a"}],
      "name"=>"rtc"}
      ]
    end

    it 'builds a javascript post aggregation' do
      @query.postagg { js('function(agg1, agg2) { return agg1 + agg2; }').as result }
      JSON.parse(@query.to_json)['postAggregations'].should == [
        {
          'type' => 'javascript',
          'name' => 'result',
          'fieldNames' => ['agg1', 'agg2'],
          'function' => 'function(agg1, agg2) { return agg1 + agg2; }'
        }
      ]
    end

    it 'raises an error when an invalid javascript function is used' do
      expect {
        @query.postagg { js('{ return a_with_b - a; }').as b }
      }.to raise_error
    end
  end

  it 'builds aggregations on long_sum' do
    @query.long_sum(:a, :b, :c)
    JSON.parse(@query.to_json)['aggregations'].should == [
      { 'type' => 'longSum', 'name' => 'a', 'fieldName' => 'a'},
      { 'type' => 'longSum', 'name' => 'b', 'fieldName' => 'b'},
      { 'type' => 'longSum', 'name' => 'c', 'fieldName' => 'c'}
    ]
  end

  it 'appends long_sum properties from aggregations on calling long_sum again' do
    @query.long_sum(:a, :b, :c)
    @query.double_sum(:x,:y)
    @query.long_sum(:d, :e, :f)
    JSON.parse(@query.to_json)['aggregations'].sort{|x,y| x['name'] <=> y['name']}.should == [
      { 'type' => 'longSum', 'name' => 'a', 'fieldName' => 'a'},
      { 'type' => 'longSum', 'name' => 'b', 'fieldName' => 'b'},
      { 'type' => 'longSum', 'name' => 'c', 'fieldName' => 'c'},
      { 'type' => 'longSum', 'name' => 'd', 'fieldName' => 'd'},
      { 'type' => 'longSum', 'name' => 'e', 'fieldName' => 'e'},
      { 'type' => 'longSum', 'name' => 'f', 'fieldName' => 'f'},
      { 'type' => 'doubleSum', 'name' => 'x', 'fieldName' => 'x'},
      { 'type' => 'doubleSum', 'name' => 'y', 'fieldName' => 'y'}
    ]
  end

  it 'removes duplicate aggregation fields' do
    @query.long_sum(:a, :b)
    @query.long_sum(:b)

    JSON.parse(@query.to_json)['aggregations'].should == [
      { 'type' => 'longSum', 'name' => 'a', 'fieldName' => 'a'},
      { 'type' => 'longSum', 'name' => 'b', 'fieldName' => 'b'},
    ]
  end

  it 'must be chainable' do
    q = [Druid::Query.new('test')]
    q.push q[-1].query_type('a')
    q.push q[-1].data_source('b')
    q.push q[-1].group_by('c')
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

  it 'takes multiple intervals' do
    @query.intervals([['2013-01-26T0', '2020-01-26T00:15'],['2013-04-23T0', '2013-04-23T15:00']])
    JSON.parse(@query.to_json)['intervals'].should == ["2013-01-26T00:00:00+00:00/2020-01-26T00:15:00+00:00", "2013-04-23T00:00:00+00:00/2013-04-23T15:00:00+00:00"]
  end

  it 'accepts Time objects for intervals' do
    @query.interval(a = Time.now, b = Time.now + 1)
    JSON.parse(@query.to_json)['intervals'].should == ["#{a.iso8601}/#{b.iso8601}"]
  end

  it 'takes a granularity from string' do
    @query.granularity('all')
    JSON.parse(@query.to_json)['granularity'].should == 'all'
  end

  it 'should take a period' do
    @query.granularity(:day, 'CEST')
    @query.properties[:granularity].should == {
      :type => "period",
      :period => "P1D",
      :timeZone => "Europe/Berlin"
    }
  end

  it 'creates a in_circ filter' do
    @query.filter{a.in_circ [[52.0,13.0], 10.0]}
    JSON.parse(@query.to_json)['filter'].should == {
    "type" => "spatial",
    "dimension" => "a",
    "bound" => {
        "type" => "radius",
        "coords" => [52.0, 13.0],
        "radius" =>  10.0
      }
    }
  end

  it 'creates a in_rec filter' do
    @query.filter{a.in_rec [[10.0, 20.0], [30.0, 40.0]] }
    JSON.parse(@query.to_json)['filter'].should == {
    "type" => "spatial",
    "dimension" => "a",
    "bound" => {
        "type" => "rectangular",
        "minCoords" => [10.0, 20.0],
        "maxCoords" => [30.0, 40.0]
      }
    }
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

  it 'creates a nin statement with and filter' do
    @query.filter{a.nin [1,2,3]}
    JSON.parse(@query.to_json)['filter'].should ==  {"fields" => [
      {"field"=>{"type"=>"selector", "dimension"=>"a", "value"=>1},"type" => "not"},
      {"field"=>{"type"=>"selector", "dimension"=>"a", "value"=>2},"type" => "not"},
      {"field"=>{"type"=>"selector", "dimension"=>"a", "value"=>3},"type" => "not"}
    ],
    "type" => "and"}
  end

  it 'creates a javascript with > filter' do
    @query.filter{a > 100}
    JSON.parse(@query.to_json)['filter'].should == {
      "type" => "javascript",
      "dimension" => "a",
      "function" => "function(a) { return(a > 100); }"
    }
  end

  it 'creates a mixed javascript filter' do
    @query.filter{(a >= 128) & (a != 256)}
    JSON.parse(@query.to_json)['filter'].should == {"fields" => [
      {"type" => "javascript", "dimension" => "a", "function" => "function(a) { return(a >= 128); }"},
      {"field" => {"type" => "selector", "dimension" => "a", "value" => 256}, "type" => "not"}
    ],
    "type" => "and"}
  end

  it 'creates a complex javascript filter' do
    @query.filter{(a >= 4) & (a <= '128')}
    JSON.parse(@query.to_json)['filter'].should == {"fields" => [
      {"type" => "javascript", "dimension" => "a", "function" => "function(a) { return(a >= 4); }"},
      {"type" => "javascript", "dimension" => "a", "function" => "function(a) { return(a <= '128'); }"}
    ],
    "type" => "and"}
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

  describe '#having' do
    it 'creates a greater than having clause' do
      @query.having{a > 100}
      JSON.parse(@query.to_json)['having'].should == {
        "type"=>"greaterThan", "aggregation"=>"a", "value"=>100
      }
    end

    it 'chains having clauses with and' do
      @query.having{a > 100}.having{b > 200}.having{c > 300}
      JSON.parse(@query.to_json)['having'].should == {
        "type" => "and",
        "havingSpecs" => [
          { "type" => "greaterThan", "aggregation" => "a", "value" => 100 },
          { "type" => "greaterThan", "aggregation" => "b", "value" => 200 },
          { "type" => "greaterThan", "aggregation" => "c", "value" => 300 }
        ]
      }
    end
  end

  it 'does not accept in with empty array' do
    expect { @query.filter{a.in []} }.to raise_error "Values cannot be empty"
  end

  it 'does raise on invalid filter statement' do
    expect { @query.filter{:a} }.to raise_error 'Not a valid filter'
  end

  it 'raises if no value is passed to a filter operator' do
    expect { @query.filter{a.eq a}.to_json}.to raise_error 'no value assigned'
  end

  it 'raises wrong number of arguments if  filter operator is called without param' do
    expect { @query.filter{a.eq}.to_json}.to raise_error
  end

  it 'should query regexp using .regexp(string)' do
    JSON.parse(@query.filter{a.regexp('[1-9].*')}.to_json)['filter'].should == {
      "dimension"=>"a",
      "type"=>"regex",
      "pattern"=>"[1-9].*"
    }
  end

  it 'should query regexp using .eq(regexp)' do
    JSON.parse(@query.filter{a.in(/abc.*/)}.to_json)['filter'].should == {
      "dimension"=>"a",
      "type"=>"regex",
      "pattern"=>"abc.*"
    }
  end

  it 'should query regexp using .in([regexp])' do
    JSON.parse(@query.filter{ a.in(['b', /[a-z].*/, 'c']) }.to_json)['filter'].should == {
      "type"=>"or",
      "fields"=>[
        {"dimension"=>"a", "type"=>"selector", "value"=>"b"},
        {"dimension"=>"a", "type"=>"regex", "pattern"=>"[a-z].*"},
        {"dimension"=>"a", "type"=>"selector", "value"=>"c"}
      ]
    }
  end

  it 'takes type, limit and columns from limit method' do
    @query.limit_spec(10, :a => 'ASCENDING', :b => 'DESCENDING')
    result = JSON.parse(@query.to_json)
    result['limitSpec'].should == {
      'type' => 'default',
      'limit' => 10,
      'columns' => [
        { 'dimension' => 'a', 'direction' => 'ASCENDING'},
        { 'dimension' => 'b', 'direction' => 'DESCENDING'}
      ]
    }
  end
end
