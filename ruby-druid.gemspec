require 'rake'

Gem::Specification.new do |gem|
  gem.name          = 'ruby-druid'
  gem.version       = '0.0.5'
  gem.date          = '2013-04-04'
  gem.summary       = 'Ruby client for druid'
  gem.description   = 'Ruby client for metamx druid'
  gem.authors       = ['Hagen Rother', 'Holger Pillmann']
  gem.email         = 'tech@madvertise.de'
  gem.homepage      = 'https://github.com/madvertise/ruby-druid'

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.require_paths = ['lib']

  gem.add_dependency 'zk'
  gem.add_dependency 'rest-client'
end
