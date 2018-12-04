require 'spec_helper'

describe "load paths: " do
  describe "with a single path" do
    before do
      @env = env_with_path_value File.expand_path('../libjs', __FILE__)
    end
    
    it "finds modules in that path" do
      @env.runtime.eval(%q|require('one').one|).should eql 'one'
    end

    it "fails when a module is not in the path" do
      lambda {
        @env.runtime.eval(%q|require('not_here')|)
      }.should raise_error(RuntimeError, /no such module 'not_here'/)
    end
  end
  
  describe "with multiple paths" do
    before do
      @env = env_with_path_value [File.expand_path('../libjs2', __FILE__), File.expand_path('../libjs', __FILE__)]
    end
    
    it "finds modules in both paths" do
      @env.runtime.eval(%q|require('two').two|).should eql 2
      @env.runtime.eval(%q|require('three').three|).should eql 'three'
    end
    
    it "respects the order in which paths were specified" do
      @env.runtime.eval(%q|require('one').one|).to_i.should eql 1
    end
  end  
end

