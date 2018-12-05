# frozen_string_literal: true

require 'mini_racer'
require_relative "mini_racer_env/version"

module CommonJS
  class MiniRacerEnv
    # Name of the top-level JS module class. This currently doesn't support a nested (dotted) name.
    # Do not hardcode this name anywhere else.
    JS_MOD = 'Module'

    attr_reader :runtime

    # Do not reuse runtime_ in other Environment instances or variables may be overwritten.
    # `:path` - JS load path. For best results, use an absolute path.
    def initialize(runtime_, path:)
      unless runtime_.is_a?(MiniRacer::Context)
        raise TypeError, "Expected a MiniRacer::Context, got #{runtime_.class}"
      end
      @runtime = runtime_
      @paths = [path].flatten.map {|pth| File.expand_path(pth) }
      setup(@runtime, @paths)
    end

    # Attaches a ruby module's own public methods and attaches them to the object named js_parent_name
    # SECURITY NOTE: Do not pass untrusted input for `js_parent_name`
    def attach_rb_functions(js_parent_name, rb_mod)
      raise TypeError  unless rb_mod.is_a? ::Module
    
      singleton = rb_mod.singleton_class
      meth_syms = rb_mod.public_methods(false).select {|meth| rb_mod.method(meth).owner == singleton }
      # NOTE: the disadvantage of `attach`ing a `Method` object or lamdba -- vs a `Proc` -- is that
      # `Proc`s will accept extra trailing args without `raise`ing `ArgumentError`, which is similar
      # to JS. To accomplish the same thing with `Method`, a method needs to be defined with a
      # trailing splat arg, e.g. `def someMethod(arg1, *ignored)`.
      meth_syms.each do |sym|
        @runtime.attach("#{js_parent_name}.#{sym}", rb_mod.public_method(sym))
      end
    end
    
    # Creates a new module named `js_mod_name` in the cache, then attaches the ruby functions to it.
    # Then the module can be `require`d by name.
    # Note that this overwrites any existing object at that cache key.
    # Returns the value of `define_cached_module`.
    # SECURITY NOTE: Do not pass untrusted input for `js_mod_name`
    def attach_rb_functions_to_mod_cache(js_mod_name, rb_mod)
      exports_qname = define_cached_module(js_mod_name)
      attach_rb_functions(%Q|#{exports_qname}|, rb_mod)
      exports_qname
    end

    # Returns the fully qualified (dotted) name to the `exports` object of the new module.
    # SECURITY NOTE: Do not pass untrusted input for `js_mod_name`
    def define_cached_module(js_mod_name)
      mod_qname = "#{JS_MOD}._cache.#{js_mod_name}"
      @runtime.eval(%Q|#{mod_qname} = new #{JS_MOD}("#{js_mod_name}")|)
      "#{mod_qname}.exports"
    end

    private

    def setup(ctx, load_paths)
      ctx.eval('__commonjs__ = {}')

      # Use to_json to escape the value
      ctx.eval("__commonjs__.loadPaths = #{load_paths.to_json}")

      # inspired by the original commonjs.rb gem.
      ctx.eval( <<~JSMOD, filename: "#{__FILE__}/#{__method__}" )
        class #{JS_MOD} {
          constructor(id) {
            this._id = id;
            this._segments = id.split("/");
            this.exports = {};
          }
          get id() { return this._id; }
          require(modId) {
            let klass = this.constructor;

            // Do not use `modId` after this line; use `expandedId`
            let expandedId = klass._expandModId(this._segments, modId);

            let mod = klass._cache[expandedId];
            if (!mod) {
              let foundPath = klass._find(__commonjs__.loadPaths, expandedId);
              let loader = (module, require, exports) => { eval(klass._loadSource(foundPath)); };
              // must be cached before loading, in case there are circular deps
              klass._cache[expandedId] = mod = new klass(expandedId);
              loader(mod, mod.require.bind(mod), mod.exports);
            }
            return mod.exports;
          }
        }

        // Install top-level `require` function
        let require = (() => {
          let topMod = new #{JS_MOD}('topMod');  // let this go out of scope
          return topMod.require.bind(topMod);
        })();
      JSMOD

      ctx.eval("#{JS_MOD}._cache = {}")  # keys are module IDs, normalized by _expandModId

      ctx.attach("#{JS_MOD}._find", proc {|load_paths, module_id|
        # Add `.js` extension if neccessary.
        target = File.extname(module_id) == '.js'  ?  module_id  :  "#{module_id}.js"
        found_file_path = load_paths.map {|path| File.join(path, target) }.
                                     detect {|filepath| File.exist?(filepath) }
        if found_file_path
          found_file_path
        else
          # Must `raise` here to halt the load process
          raise "no such module '#{module_id}'"
        end
      })

      ctx.attach("#{JS_MOD}._loadSource", proc {|path|
        # For better error messages, we include the magic V8 sourceURL comment.
        # See https://bugs.chromium.org/p/v8/issues/detail?id=2948
        File.read(path) + "\n//# sourceURL=#{path}"
      })

      ctx.attach("#{JS_MOD}._expandModId", proc {|segments, module_id|
        mod_segs = module_id.split('/')
        if mod_segs.any? {|seg| seg == '.' || seg == '..' }
          # Has relative path segments, so treat as relative to the `segments` of the calling module
          # Careful - the `each_with_object` arg is modified
          module_id.split('/').each_with_object(segments[0..-2]) {|element, path|
            if element == '.'
              # do nothing
            elsif element == '..'
              path.pop
            else
              path.push element
            end
          }.join('/')
        else
          module_id
        end
      })
    end
  end
end

