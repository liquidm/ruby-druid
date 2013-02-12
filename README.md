# Ruby-druid

  Ruby query DSL for metamx druid.

ruby druid generates complet JSON queries by chaining methods.
The JSON can be send directly to  a druid server or handled seperatly.

## Getting started

In your Gemfile:

```ruby
  gem 'ruby-druid'
```

In your code:

```ruby
  require 'druid'
```

## Usage

```ruby
Druid::Client.new('host:port').query('dataSource')
```

returns a query Object on which all other methods can be called to create a full and valid druid query

a query object can be send by calling its send method id it was build by a client or by handing it as a param to the send method of a Client

```ruby
Druid::Client.new('host:port').query('dataSource').send
#or
client = Druid::Client.new('host:port')
query = Druid::Query.new('dataSource')
client.send(query)
```

the send method returns the parsed response from the druid server as an array
if the response is not empty it contains one ResponseRow object for each row
the timestamp by can be received by a method with the same name
the other by hashlike key, value syntax on the ResponseRow object

```ruby
client.send(query).long_sum('aggregate1').map do |response_row|
  puts response_row.timestamp
  puts response_row['aggregate1']
end
```

### group_by

sets the dimensions to group the data

queryType is set automatically to 'groupBy' by the group_by 

```ruby
Druid::Query.new('test/test').group_by([:dimension1, :dimension2])
```

### long_sum

```ruby
Druid::Query.new('test/test').long_sum([:aggregate1, :aggregate2])
```

### post_aggregations

a simple syntax for post aggregations with +,-,/,* can be used like:

```ruby
Druid::Query.new('test/test').long_sum([:aggregate1, :aggregate2]).postaggregation{(aggregate2 + aggregate2).as output_field_name}
```

it is necessary to aggregate all fields from a postaggregation with long_sum

### interval

the interval for the query takes String with date and time or objects that provide a iso8601 method 

```ruby
Druid::Query.new('test/test').long_sum(:aggregate1).interval("2013-07-03T00", Time.now)
```

### granularity

granularity can be  :all, :none, :minute, :fifteen_minute, :thirthy_minute, :hour and :day

```ruby
Druid::Query.new('test/test').long_sum(:aggregate1).granularity(:day)
```

## filters

filters are set by the filter method. it takes a block or a hash as parameters

filters can be chained filter{...}.filter{...}

### filter == , eq

```ruby
Druid::Query.new('test/test').filter{a.eq 1}

#this is the same as

Druid::Query.new('test/test').filter{a == 1}
```

### filter != , neq

```ruby
Druid::Query.new('test/test').filter{a.neq 1}

#this is the same as

Druid::Query.new('test/test').filter{a != 1}
```

### filter and

a logical or than can combine all other filters

```ruby
Druid::Query.new('test/test').filter{a.neq 1 & b.neq 2}
```

### filter or

a logical or than can combine all other filters

```ruby
Druid::Query.new('test/test').filter{a.neq 1 | b.neq 2}
```

### filter not

a logical not than can negate all other filter

```ruby
Druid::Query.new('test/test').filter{!a.eq(1)}
```

### filter in

This filter creates a set of equals filters in an and filter.

```ruby
Druid::Query.new('test/test').filter{a.in(1,2,3)}
```

### filter with hash syntax

sometimes it can be useful to use a hash syntax for filtering
for example if you already get them from a list or parameterhash

```ruby
Druid::Query.new('test/test').filter{a => 1, b =>2, c => 3}

#this is the same as

Druid::Query.new('test/test').filter{a.eq(1) & b.eq(2)}
```
## Contributions

ruby- druid is developed by madvertise Mobile Advertising GmbH

You can support us on different ways:

* Use ruby-druid, and let us know if you encounter anything that's broken or missing.
  A failing spec is great. A pull request with your fix is even better!
* Spread the word about ruby-druid on Twitter, Facebook, and elsewhere.
* Work with us at madvertise on awesome stuff like this.
  [Read the job description](http://madvertise.com/en/2013/02/07/software-developer-ruby-fm) and send a mail to careers@madvertise.com.

