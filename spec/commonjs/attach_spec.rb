require 'spec_helper'

describe "attaching ruby module functions" do
  let(:env) { env_with_path_value '.' }
  let(:runtime) { env.runtime }
  let(:rb_mod) do
    Module.new do
      def self.plusTwo(n); n + 2; end
      def self.timesTwo(n); n * 2; end
    end
  end

  describe "attach_rb_functions" do
    it "can attach at top level" do
      env.attach_rb_functions('arith', rb_mod)
      expect( runtime.eval('arith.plusTwo(100)') ).to eql 102
      expect( runtime.eval('arith.timesTwo(101)') ).to eql 202
    end

    it "can attach under arbitrary object" do
      runtime.eval('let foo = {arith: {}}')
      env.attach_rb_functions('foo.arith', rb_mod)
      expect( runtime.eval('foo.arith.plusTwo(100)') ).to eql 102
      expect( runtime.eval('foo.arith.timesTwo(101)') ).to eql 202
    end

    it "can attach via bracket-style accessor" do
      runtime.eval('let foo = {arith: {}}')
      env.attach_rb_functions('foo["arith"]', rb_mod)
      expect( runtime.eval('foo.arith.plusTwo(100)') ).to eql 102
      expect( runtime.eval('foo.arith.timesTwo(101)') ).to eql 202
    end
  end

  context "attach_rb_functions_to_mod_cache" do
    it "works in basic case" do
      mod_name = 'arith'
      exports_qname = env.attach_rb_functions_to_mod_cache(mod_name, rb_mod)
      expect(exports_qname).to eq "Module._cache[\"#{mod_name}\"].exports"
      expect( runtime.eval("typeof(#{mod_name})") ).to eq 'undefined'  # not at top level
      expect( runtime.eval(%Q|require("#{mod_name}").plusTwo(100)|) ).to eql 102
      expect( runtime.eval(%Q|require("#{mod_name}").timesTwo(101)|) ).to eql 202
    end

    it "works with hyphenated module name" do
      mod_name = 'arith-util'
      exports_qname = env.attach_rb_functions_to_mod_cache(mod_name, rb_mod)
      expect(exports_qname).to eq "Module._cache[\"#{mod_name}\"].exports"
      expect( runtime.eval(%Q|require("#{mod_name}").plusTwo(100)|) ).to eql 102
      expect( runtime.eval(%Q|require("#{mod_name}").timesTwo(101)|) ).to eql 202
      skip
    end
  end
end
