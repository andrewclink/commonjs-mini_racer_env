# -*- encoding: utf-8 -*-
require File.expand_path('../lib/commonjs/mini_racer_env/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Charles Lowell", "Kelvin Liu"]
  #gem.email         = ["cowboyd@thefrontside.net"]
  gem.description   = "Host CommonJS JavaScript environments in Ruby via MiniRacer"
  gem.summary       = "Provide access to your Ruby and Operating System runtime via the commonjs API"
  #gem.homepage      = "http://github.com/cowboyd/commonjs.rb"
  gem.license       = "MIT"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "commonjs-mini_racer_env"
  gem.require_paths = ["lib"]
  gem.version       = CommonJS::MiniRacerEnv::VERSION

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if gem.respond_to?(:metadata)
    gem.metadata["allowed_push_host"] = "PUSH_DISABLED"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_dependency 'mini_racer', '>= 0.2.4'

  gem.add_dependency 'byebug'
  gem.add_dependency 'pry'
  gem.add_dependency 'pry-rescue'
  gem.add_dependency 'pry-stack_explorer'
  gem.add_dependency 'pry-byebug'
  
  

end
