# -*- encoding: utf-8 -*-
require File.expand_path('../lib/commonjs/mini_racer_env/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Charles Lowell", "Kelvin Liu"]
  #gem.email         = ["cowboyd@thefrontside.net"]
  gem.description   = "Host CommonJS JavaScript environments in Ruby"
  gem.summary       = "Provide access to your Ruby and Operating System runtime via the commonjs API"
  #gem.homepage      = "http://github.com/cowboyd/commonjs.rb"
  gem.license       = "MIT"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "commonjs"
  gem.require_paths = ["lib"]
  gem.version       = CommonJS::MiniRacerEnv::VERSION

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  # TODO: constrain version?
  gem.add_dependency 'mini_racer'
end