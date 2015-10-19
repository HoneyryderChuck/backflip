# -*- encoding: utf-8 -*-
require File.expand_path('../lib/backflip/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tiago Cardoso"]
  gem.email         = ["cardoso_tiago@hotmail.com"]
  gem.summary       = "background processing for Ruby"
  gem.description   = "background processing for Ruby."
  gem.homepage      = ""
  gem.license       = "LGPL-3.0"

  gem.executables   = ['backflip']
  gem.files         = `git ls-files`.split("\n") - Dir['tmp/**/*']
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "backflip"
  gem.require_paths = ["lib"]
  gem.version       = Backflip::VERSION
  gem.add_dependency                  'redis', '~> 3.2', '>= 3.2.1'
  gem.add_dependency                  'redis-namespace', '~> 1.5', '>= 1.5.2'
  gem.add_dependency                  'connection_pool', '~> 2.2', '>= 2.2.0'
  gem.add_dependency                  'sidekiq', '~> 3.5', '>= 3.5.0'
  gem.add_dependency                  'celluloid-io', '~> 0.17.2'
  gem.add_dependency                  'json', '~> 1.0'
  gem.add_development_dependency      'rake', '~> 10.0'
  gem.add_development_dependency      'rspec', '~> 3.3.0'
end
