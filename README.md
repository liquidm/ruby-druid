# ruby-druid

A ruby client for [druid](http://druid.io).

ruby-druid features a [Squeel](https://github.com/ernie/squeel)-like query DSL
and generates a JSON query that can be sent to druid directly. A console for
testing is also provided.

[![Gem Version](https://badge.fury.io/rb/ruby-druid.png)](http://badge.fury.io/rb/ruby-druid)
[![Build Status](https://travis-ci.org/liquidm/ruby-druid.png)](https://travis-ci.org/liquidm/ruby-druid)
[![Code Climate](https://codeclimate.com/github/liquidm/ruby-druid.png)](https://codeclimate.com/github/liquidm/ruby-druid)
[![Dependency Status](https://gemnasium.com/liquidm/ruby-druid.png)](https://gemnasium.com/liquidm/ruby-druid)

## Installation

Add this line to your application's Gemfile:

    gem 'ruby-druid'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruby-druid

## Usage

```ruby
Druid::Client.new('zk1:2181,zk2:2181/druid').query('service/source')
```

returns a query object on which all other methods can be called to create a
full and valid druid query.

A query object can be sent like this:

```ruby
client = Druid::Client.new('zk1:2181,zk2:2181/druid')
query = Druid::Query.new('service/source')
client.send(query)
```

The `send` method returns the parsed response from the druid server as an
array.  If the response is not empty it contains one `ResponseRow` object for
each row.  The timestamp by can be received by a method with the same name
(i.e. `row.timestamp`), all row values by hashlike syntax (i.e.
`row['dimension'])

### GroupBy

A [GroupByQuery](https://github.com/metamx/druid/wiki/GroupByQuery) sets the
dimensions to group the data.

`queryType` is set automatically to `groupBy`.

```ruby
Druid::Query.new('service/source').group_by([:dimension1, :dimension2])
```

### TimeSeries

A [TimeSeriesQuery](https://github.com/metamx/druid/wiki/TimeseriesQuery)
returns an array of JSON objects where each object represents a value asked for
by the timeseries query.

```ruby
Druid::Query.new('service/source').time_series([:aggregate1, :aggregate2])
```

### Aggregations

```ruby
Druid::Query.new('service/source').long_sum([:aggregate1, :aggregate2])
```

### Post Aggregations

A simple syntax for post aggregations with +,-,/,* can be used like:

```ruby
query = Druid::Query.new('service/source').long_sum([:aggregate1, :aggregate2])
query.postagg{(aggregate2 + aggregate2).as output_field_name}
```

Required fields for the postaggregation are fetched automatically by the
library.

### Query Interval

The interval for the query takes a string with date and time or objects that
provide an `iso8601` method.

```ruby
query = Druid::Query.new('service/source').long_sum(:aggregate1)
query.interval("2013-01-01T00", Time.now)
```

### Result Granularity

The granularity can be `:all`, `:none`, `:minute`, `:fifteen_minute`,
`:thirthy_minute`, `:hour` or `:day`.

It can also be a period granularity as described in the [druid
wiki](https://github.com/metamx/druid/wiki/Granularities).

The period `'day'` or `:day` will be interpreted as `'P1D'`.

If a period granularity is specifed, the (optional) second parameter is a time
zone. It defaults to the machines local time zone. i.e.

```ruby
query = Druid::Query.new('service/source').long_sum(:aggregate1)
query.granularity(:day)
```

is (on my box) the same as

```ruby
query = Druid::Query.new('service/source').long_sum(:aggregate1)
query.granularity('P1D', 'Europe/Berlin')
```

### Having

```ruby
Druid::Query.new('service/source').having{metric > 10}
```

```ruby
Druid::Query.new('service/source').having{metric < 10}
```

### Filters

Filters are set by the `filter` method. It takes a block or a hash as
parameter.

Filters can be chained `filter{...}.filter{...}`

#### Base Filters

```ruby
# equality
Druid::Query.new('service/source').filter{dimension.eq 1}
Druid::Query.new('service/source').filter{dimension == 1}
```

```ruby
# inequality
Druid::Query.new('service/source').filter{dimension.neq 1}
Druid::Query.new('service/source').filter{dimension != 1}
```

```ruby
# greater, less
Druid::Query.new('service/source').filter{dimension > 1}
Druid::Query.new('service/source').filter{dimension >= 1}
Druid::Query.new('service/source').filter{dimension < 1}
Druid::Query.new('service/source').filter{dimension <= 1}
```

```ruby
# JavaScript
Druid::Query.new('service/source').filter{a.javascript('dimension >= 1 && dimension < 5')}
```

#### Compound Filters

Filters can be combined with boolean logic.

```ruby
# and
Druid::Query.new('service/source').filter{dimension.neq 1 & dimension2.neq 2}
```

```ruby
# or
Druid::Query.new('service/source').filter{dimension.neq 1 | dimension2.neq 2}
```

```ruby
# not
Druid::Query.new('service/source').filter{!dimension.eq(1)}
```

#### Inclusion Filter

This filter creates a set of equals filters in an and filter.

```ruby
Druid::Query.new('service/source').filter{dimension.in(1,2,3)}
```

#### Hash syntax

Sometimes it can be useful to use a hash syntax for filtering
for example if you already get them from a list or parameter hash.

```ruby
Druid::Query.new('service/source').filter{dimension => 1, dimension1 =>2, dimension2 => 3}

#this is the same as

Druid::Query.new('service/source').filter{dimension.eq(1) & dimension1.eq(2) & dimension2.eq(3)}
```

### DRIPL

ruby-druid now includes a [REPL](https://github.com/cldwalker/ripl):

```ruby
$ bin/dripl
>> metrics
[
    [0] "actions"
]

>> dimensions
[
    [0] "actions"
]

>> long_sum(:actions)
+---------+
| actions |
+---------+
|   98575 |
+---------+

>> long_sum(:actions)[-7.days].granularity(:day)
+-------------------------------+----------+
| timestamp                     | actions  |
+-------------------------------+----------+
| 2013-03-28T00:00:00.000+01:00 |   93371  |
| 2013-03-29T00:00:00.000+01:00 |   448200 |
| 2013-03-30T00:00:00.000+01:00 |   117167 |
| 2013-03-31T00:00:00.000+01:00 |   828321 |
| 2013-04-01T00:00:00.000+02:00 |   261578 |
| 2013-04-02T00:00:00.000+02:00 |   05149  |
| 2013-04-03T00:00:00.000+02:00 |   27512  |
| 2013-04-04T00:00:00.000+02:00 |   18897  |
+-------------------------------+----------+

>> long_sum(:actions)[-7.days].granularity(:day).properties
{
      :dataSource => "events",
     :granularity => {
            :type => "period",
          :period => "P1D",
        :timeZone => "Europe/Berlin"
    },
       :intervals => [
        [0] "2013-03-28T00:00:00+01:00/2013-04-04T11:57:20+02:00"
    ],
       :queryType => :groupBy,
    :aggregations => [
        [0] {
                 :type => "longSum",
                 :name => :actions,
            :fieldName => :actions
        }
    ]
}
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
