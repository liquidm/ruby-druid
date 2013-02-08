require 'rake'

Gem::Specification.new do |s|
  s.name        = 'ruby-druid'
  s.version     = '0.0.1'
  s.date        = '2013-01-28'
  s.summary     = "Ruby DSL for druid"
  s.description = "Collection of ruby-based tools and libraries for metamx druid"
  s.authors     = ['Hagen Rother', 'Holger Pillmann']
  s.email       = 'tech@madvertise.de'
  s.files       = ['lib/druid.rb']
  s.add_dependency 'zk'
  s.add_dependency 'rest-client'
  s.homepage    = 'http://www.madvertise.de'
end