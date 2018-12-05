# frozen_string_literal: true

require 'commonjs-mini_racer_env'
require 'pathname'

def env_with_path_value(path)
  CommonJS::MiniRacerEnv.new new_runtime, path: path
end

def new_runtime
  MiniRacer::Context.new
end
