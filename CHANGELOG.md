### 0.1.3

* dripl improvements
  * Fixed badly formatted output for rows with missing values
  * Changed display of responses where granularity is set

### 0.1.1

* Zookeeper connection issues
  * Fixed the issue where ZK connections weren't closed after the client was initialized. The new flow opens a connection to ZK then closes it once it has a list of data sources. To keep the connection open with ZK please use the options `zk_keepalive: true`
* Added Time Series query support. You can now use `.time_series(aggregations)` for time series based queries
