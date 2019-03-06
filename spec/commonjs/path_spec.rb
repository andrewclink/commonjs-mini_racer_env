require 'spec_helper'

describe "load paths: " do
  describe "with a single path" do
    before do
      @env = env_with_path_value File.expand_path('../libjs', __FILE__)
    end
    
    it "finds modules with index.js" do
      expect( @env.runtime.eval(%q|require('thing').thing|)).to eql 'works'
    end
    
    it "resolves relative paths" do
      expect( @env.runtime.eval(%q|require('thing/target')|)).to eql 'thing/sibling'
    end
    
    it "finds modules in that path" do
      expect( @env.runtime.eval(%q|require('one').one|) ).to eql 'one'
    end

    it "fails when a module is not in the path" do
      expect {
        @env.runtime.eval(%q|require('not_here')|)
      }.to raise_error(RuntimeError, /no such module 'not_here'/)
    end

    it "works with a module name containing hyphens" do
      expect( @env.runtime.eval(%q|require('i-am-special').name|) ).to eql 'I am special'
    end
  end
  
  describe "with multiple paths" do
    before do
      @env = env_with_path_value [File.expand_path('../libjs2', __FILE__), File.expand_path('../libjs', __FILE__)]
    end
    
    it "finds modules in both paths" do
      expect( @env.runtime.eval(%q|require('two').two|) ).to eql 2
      expect( @env.runtime.eval(%q|require('three').three|) ).to eql 'three'
    end
    
    it "respects the order in which paths were specified" do
      result = @env.runtime.eval(%q|require('one').one|)
      puts "got result #{result.inspect}"
      expect( result.to_i ).to eql 1
    end
  end  
end

