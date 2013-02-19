# Ruby-druid

  Ruby query DSL for metamx druid.

ruby druid generates complete JSON queries by chaining methods.
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
Druid::Client.new('zk1:2181,zk2:2181/druid').query('service/source')
```

returns a query object on which all other methods can be called to create a full and valid druid query.

A query object can be sent like this:

```ruby
Druid::Client.new('zk1:2181,zk2:2181/druid').query('service/source').send
#or
client = Druid::Client.new('zk1:2181,zk2:2181/druid')
query = Druid::Query.new('service/source')
client.send(query)
```

The `send` method returns the parsed response from the druid server as an array.
If the response is not empty it contains one `ResponseRow` object for each row.
The timestamp by can be received by a method with the same name (i.e. `row.timestamp`),
all row values by hashlike syntax (i.e. `row['dimension'])

### group_by

Sets the dimensions to group the data.

`queryType` is set automatically to `groupBy`.


```ruby
Druid::Query.new('service/source').group_by([:dimension1, :dimension2])
```

### long_sum

```ruby
Druid::Query.new('service/source').long_sum([:aggregate1, :aggregate2])
```

### postagg

A simple syntax for post aggregations with +,-,/,* can be used like:

```ruby
query = Druid::Query.new('service/source').long_sum([:aggregate1, :aggregate2])

query.postagg{(aggregate2 + aggregate2).as output_field_name}
```

It is required to aggregate all fields from a postaggregation with `long_sum`.

### interval

The interval for the query takes a string with date and time or objects that provide a `iso8601` method 

```ruby
query = Druid::Query.new('service/source').long_sum(:aggregate1)

query.interval("2013-07-03T00", Time.now)
```

### granularity

granularity can be `:all`, `:none`, `:minute`, `:fifteen_minute`, `:thirthy_minute`, `:hour` or `:day`.

```ruby
query = Druid::Query.new('service/source').long_sum(:aggregate1)

query.granularity(:day)
```

## filter

Filters are set by the `filter` method. It takes a block or a hash as parameter.

Filters can be chained `filter{...}.filter{...}`

### filter == , eq

```ruby
Druid::Query.new('service/source').filter{a.eq 1}

#this is the same as

Druid::Query.new('service/source').filter{a == 1}
```

### filter != , neq

```ruby
Druid::Query.new('service/source').filter{a.neq 1}

#this is the same as

Druid::Query.new('service/source').filter{a != 1}
```

### filter and

a logical or than can combine all other filters

```ruby
Druid::Query.new('service/source').filter{a.neq 1 & b.neq 2}
```

### filter or

a logical or than can combine all other filters

```ruby
Druid::Query.new('service/source').filter{a.neq 1 | b.neq 2}
```

### filter not

a logical not than can negate all other filter

```ruby
Druid::Query.new('service/source').filter{!a.eq(1)}
```

### filter in

This filter creates a set of equals filters in an and filter.

```ruby
Druid::Query.new('service/source').filter{a.in(1,2,3)}
```

### filter with hash syntax

sometimes it can be useful to use a hash syntax for filtering
for example if you already get them from a list or parameterhash

```ruby
Druid::Query.new('service/source').filter{a => 1, b =>2, c => 3}

#this is the same as

Druid::Query.new('service/source').filter{a.eq(1) & b.eq(2)}
```
## Contributions

ruby-druid is developed by madvertise Mobile Advertising GmbH

You can support us on different ways:

* Use ruby-druid, and let us know if you encounter anything that's broken or missing.
  A failing spec is great. A pull request with your fix is even better!
* Spread the word about ruby-druid on Twitter, Facebook, and elsewhere.
* Work with us at madvertise on awesome stuff like this.
  [Read the job description](http://madvertise.com/en/2013/02/07/software-developer-ruby-fm) and send a mail to careers@madvertise.com.
