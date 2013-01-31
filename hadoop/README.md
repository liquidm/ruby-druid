Batch config generator
======================

When you start to use [batch ingestion](https://github.com/metamx/druid/wiki/Batch-ingestion),
you'll quickly notice, you will need to edit the batch config for each run.

The `create-template.rb` takes any iso formated date as parameter (will default to system time)
and convert the `importer.template` into a `druidimport.conf` as described
[here](https://github.com/metamx/druid/wiki/Batch-ingestion)

Once you adjusted the template to your needs (pay special attention to `granularitySpec` and `pathSpec`)
you can use it as part of a cron job

```
./create-template.rb
java -cp hadoop_config_path:druid_indexer_selfcontained_jar_path com.metamx.druid.indexer.HadoopDruidIndexerMain  ./druidimport.conf
```