dumbo.rb, the druid batch config generator
==========================================

When you start to use [batch ingestion](https://github.com/metamx/druid/wiki/Batch-ingestion),
you'll quickly notice, you will need to edit the batch config for each run.

Also, it's unreliable and needs lots of fiddling.

dumbo.rb actually checks your hdfs against your s3 and computes what's needed.

currently dumbo.rb does not take any configuration what so ever, you need to change the code and
there are lots of implicit assumptions. Heck, it's not even tested yet :)

USE AT YOUR OWN RISK

Once you adjusted the `importer.template` to your needs (pay special attention to `granularitySpec` and `pathSpec`)
you can use it as part of a cron job

```
ruby ./dumbo.rb
CLASSPATH= hadoop_config_path:druid_indexer_selfcontained_jar_path com.metamx.druid.indexer.HadoopDruidIndexerMain
java -cp $CLASSPATH ./druidimport.conf
```