require 'rake'

Gem::Specification.new do |s|
  s.name        = 'ruby-druid'
  s.version     = '0.0.2'
  s.date        = '2013-02-19'
  s.summary     = "Ruby client for druid"
  s.description = "Collection of ruby-based tools and libraries for metamx druid"
  s.authors     = ['Hagen Rother', 'Holger Pillmann']
  s.email       = 'tech@madvertise.de'
  s.files       = [
    'lib/druid.rb',
    'lib/druid/client.rb',
    'lib/druid/query.rb',
    'lib/druid/response_row.rb',
    'lib/druid/zoo_handler.rb'
  ]
  s.add_dependency 'zk'
  s.add_dependency 'rest-client'
  s.homepage    = 'http://www.madvertise.de'
end