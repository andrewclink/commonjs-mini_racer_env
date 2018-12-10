#!/usr/bin/env rake
require "bundler/gem_tasks"

ENV['gem_push'] = 'false'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new('spec') do |spec|
  spec.rspec_opts = ['--color', "--format documentation"]
end

task default: :spec
