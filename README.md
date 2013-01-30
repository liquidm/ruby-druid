Early stages of ruby support library for metamx druid

What we got so far:
`
require "./druid"

puts Druid::Query.new(:source).group(:group1, :group2).
  long_sum(:sum1, :sum2).
  interval("2013-01-26T00", "2020-01-26T00:15").
  granularity(:day).filter{foo.in(1, 2) & bar.eq(3)}.
  to_json

`

Outputs:
`
{
  "dataSource": "source",
  "queryType": "groupBy",
  "dimensions": ["group1", "group2"],
  "aggregations": [{
    "type": "longSum",
    "name": "sum1",
    "fieldName": "sum1"
  }, {
    "type": "longSum",
    "name": "sum2",
    "fieldName": "sum2"
  }],
  "intervals": ["2013-01-26T00:00:00+00:00/2020-01-26T00:15:00+00:00"],
  "granularity": "day",
  "filter": {
    "type": "and",
    "fields": [{
      "type": "or",
      "fields": [{
        "type": "selector",
        "dimension": "foo",
        "value": 1
      }, {
        "type": "selector",
        "dimension": "foo",
        "value": 2
      }]
    }, {
      "type": "selector",
      "dimension": "bar",
      "value": 3
    }]
  }
}
`