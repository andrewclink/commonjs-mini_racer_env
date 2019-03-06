require 'byebug'
require 'pry'
require 'pry-rescue'
require 'pry-stack_explorer'
require 'pry-byebug'

# frozen_string_literal: true

require 'mini_racer'
require_relative "mini_racer_env/version"
require_relative "mini_racer_env/string"

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
    # Note that this overrides any existing object at that cache key (but does not delete them)
    # Returns the value of `define_cached_module`.
    # SECURITY NOTE: Do not pass untrusted input for `js_mod_name`
    def attach_rb_functions_to_mod_cache(js_mod_name, rb_mod)
      js_mod_name = "*" + js_mod_name
      exports_qname = define_cached_module(js_mod_name)
      attach_rb_functions(%Q|#{exports_qname}|, rb_mod)
      exports_qname
    end

    # Returns the fully qualified (dotted) name to the `exports` object of the new module.
    # SECURITY NOTE: Do not pass untrusted input for `js_mod_name`
    def define_cached_module(js_mod_name)
      # use bracket-syntax to handle non-identifier chars, e.g. 'source-map'
      mod_qname = "#{JS_MOD}._cache[#{js_mod_name.inspect}]"
      puts "define_cached_module(#{js_mod_name.inspect}) -> mod_qname= #{mod_qname}"
      @runtime.eval(%Q|#{mod_qname} = new #{JS_MOD}("#{js_mod_name}")|)
      "#{mod_qname}.exports"
    end

    private

    def setup(ctx, load_paths)

      console_logger = proc {|*args| 
        msg_transform = if args.first.is_a?(Symbol)
          args.shift
        else
          :blue
        end
        
        msg = ""
        msg = args.shift if args.first.is_a?(String)
        str = args.collect do |arg|
          case arg
          when String
            arg.inspect
          when Hash
            arg.inspect.red
          when Numeric
            arg.to_s.blue
          when Array
            "[#{arg.collect(&:inspect).join(', ')}]".red
          when MiniRacer::JavaScriptFunction 
            "[function #{arg.to_s}]".red
          else
            "[#{arg.class}]".red
          end
        end.join(", ")
        
        puts "console: ".send(msg_transform) + msg + " " + str
      }
      
      ctx.attach 'console.log', console_logger
      ctx.attach 'console.success', proc {|*args| console_logger.call(*args.unshift(:green))  }
      ctx.attach 'console.warn',    proc {|*args| console_logger.call(*args.unshift(:yellow)) }
      ctx.attach 'console.error',   proc {|*args| console_logger.call(*args.unshift(:red)) }
      
      ctx.eval('__commonjs__ = {}')

      # Use to_json to escape the value
      ctx.eval("__commonjs__.loadPaths = #{load_paths.to_json}")

      # inspired by the original commonjs.rb gem.
      ctx.eval(File.read(File.join(File.dirname(__FILE__), "./setup.js")) , filename: "setup.js" )

      ctx.eval("#{JS_MOD}._cache = {}")  # keys are module IDs, normalized by _expandModId
      
      ctx.attach("#{JS_MOD}._findPackage", proc{|load_paths, loader_id, segments, module_id| 
        # Logger
        # def log(*args); puts "_findPackage: ".red + args.join(" ") end
        def log(*args) end
        log "looking for #{module_id} with loader_id '#{loader_id}'"
        
        # We need to get the expandedId for caching
        found_path  = nil
        expanded_id = module_id

        #debug
        # if './lib/_stream_readable.js' == module_id
        #   binding.pry
        # end

        # Create an intermediate path. We have load_paths + intermediate_path + target.
        # This also serves to relativize paths. Segments starting with $ are auto-resolved
        # and should be removed
        #
        segments = loader_id.split('/')
        mod_segs = module_id.split('/')
        target   = mod_segs.pop
        intermediate_path = if mod_segs.any? {|seg| seg == '.' || seg == '..' }
          
          # Do we need to remove the last segment to search relatively?
          if segments.count > 1 && segments.last[0] == '$'
            segments = segments[0...-1]
          end

          log "have segments: #{segments}, mod_segs: #{mod_segs}"
          relative_path = module_id.split('/')[0...-1]
          relative_path.each_with_object(segments) {|element, path|
            if element == '.'
              # do nothing
            elsif element == '..'
              path.pop
            else
              path.push element
            end
          }.join('/')
        else
          mod_segs.join('/')
        end
        log "=> mod_segs: #{mod_segs.inspect}"
        log "=> created intermediate path: #{intermediate_path.inspect}"
        
        
        # Also look for path/+loader_id+/file
        # Inject loader_id into paths
        # [asdf/test, qwer/test] => [asdf/test, asdf/test/loader_id, qwer/test/loader_id]
        #
        #load_paths = load_paths.zip(load_paths).collect{|x| [x[0], File.join(x[1], loader_id)]}.flatten unless loader_id == 'topMod'
        load_paths.each do |path|
          log "[#{module_id}] -> looking in path #{path}"
          # Try just sticking module_id on the load path.
          tmp = File.join(path, intermediate_path, target) 
          log "[#{module_id}] ->  Checking #{tmp}"
          
          # Try file.js first in case there is a directory structure like:
          # module/
          #    something.js
          #    something/
          #        version.js
          #
          log "[#{module_id}] ->  Checking #{tmp}.js"
          if File.extname(tmp).length < 1 && File.exists?(tmp + '.js')
            found_path = tmp + '.js'
            module_id = "#{intermediate_path}/$#{target}"
            break
          end
          
          # Now look for module_id if it was specified as "something.js" or
          # look for a package with something/package.json or something/index.js
          #
          if File.exists?(tmp)
            found_path = tmp
            module_id = File.join(intermediate_path, '$' + target)
            
            if File.directory?(tmp)
              # Look for package.json
              pkg_json = File.join(tmp, intermediate_path, 'package.json')
              log "[#{module_id}] -> Looking for package.json"
              if File.exists?(pkg_json) && (package_info = JSON.parse(File.read(pkg_json))) && !package_info['main'].nil? #rescue false
                log "[#{module_id}] -> Reading package.json"
                main_js = File.join(tmp, intermediate_path, package_info['main'])
                if File.exists?(main_js)
                  # Intermediate path needs to contain the source path, not module_id.
                  # E.g.: load_path/intermediate/dist/vue.prod.js
                  #       `dist` needs to go <- to intermediate, not -> to module_id
                  #
                  main_path = package_info['main'].split('/')[0...-1].join('/')
                  log "[#{module_id}] -> adding main_path to intermediate_path: #{intermediate_path.red} + #{main_path.red}"
                  intermediate_path = File.join(intermediate_path, main_path)
                  found_path = main_js
                  module_id = File.join(target, intermediate_path, "$main")
                  break
                else
                  log "[#{module_id}] -> package.json main entry file not found (#{main_js})".red
                end
              end
              
              # Look for index.js
              index_js = File.join(tmp, intermediate_path, 'index.js')
              if File.exists?(index_js) 
                found_path = index_js
                module_id = "#{target}/$index"
                break
              end
              
              # Couldn't resolve directory.
              log "[#{module_id}] -> Couldn't resolve directory".red
              found_path = nil
            end

            break
          end
          

        end
                
        # Must `raise` here to halt the load process
        if found_path.nil?
          log "NOT FOUND:".red + " Could not find #{module_id}"
          raise "no such module '#{module_id}'" 
        end
        
        module_id = module_id[0...-3] if module_id[-3..-1] == '.js'
        log "resolved #{module_id} => #{found_path}"
        {id: module_id, path: found_path}
      })

      ctx.attach("#{JS_MOD}._find", proc {|loader_id, load_paths, module_id|
        begin
        # Add `.js` extension if neccessary.
                
        # target = File.extname(module_id) == '.js'  ?  module_id  :  "#{module_id}.js"
        # found_file_path = load_paths.map {|path| x = File.join(path, target); puts "Searching path: #{path}, target: #{target} => #{x}"; x }.
        #                              detect {|filepath| File.exist?(filepath) }

        found_file_path = nil
        
        # Also look for path/+loader_id+/file
        # Inject loader_id into paths
        # [asdf/test, qwer/test] => [asdf/test, asdf/test/loader_id, qwer/test/loader_id]
        #
        load_paths = load_paths.zip(load_paths).collect{|x| [x[0], File.join(x[1], loader_id)]}.flatten
        
        load_paths.each do |path|
          puts "-> Searching path: #{path.inspect} for #{module_id.inspect}"
          # Look for the file
          tmp = File.join(path, module_id)
          puts "-> Trying: #{tmp}"
          if File.exists?(tmp)
            unless File.directory?(tmp)
              found_file_path = tmp
              break
            else
              # Try package.json
              json = File.join(path, module_id, "package.json")
              puts "-> Trying JSON: #{json}"
              if File.exists?(json)
                package_info = JSON.parse(File.read(json))
                
                if !package_info['main'].nil?
                  package_main = File.join(path, module_id, package_info['main'])
                  puts "-> Resolved main: #{package_main}"
                  if File.exists?(package_main)
                    found_file_path = package_main 
                    break
                  end
                elsif File.exists?(File.join(path, module_id, 'index.js'))
                  found_file_path = File.join(path, module_id, 'index.js')
                  break
                end
              end
              
            end
          end
          
          # Look for file -> file.js
          if module_id[-3..-1] != '.js'
            tmp = File.join(path, "#{module_id}.js")
            puts "-> Trying: #{tmp}"
            if File.exists?(tmp)
              found_file_path = tmp
              break 
            end
          end          

        end


        
        if found_file_path
          found_file_path
        else
          # Must `raise` here to halt the load process
          raise "no such module '#{module_id}'"
        end
        
      rescue Exception => e
        log "Exception: ".red + e.message
        binding.pry
      end
      })

      ctx.attach("#{JS_MOD}._expandModId", proc {|segments, module_id, loader_id|
        
        # binding.pry
        
        mod_segs = module_id.split('/')
        if mod_segs.any? {|seg| seg == '.' || seg == '..' }
          # Has relative path segments, so treat as relative to the `segments` of the calling module
          # Careful - the `each_with_object` arg is modified
          lookup_segs = segments[0...-1]
          # lookup_segs.push(segments.last) if module_id[0] == '.' &&
          puts "-> (in #{loader_id.inspect}) segments: #{segments}, considering #{lookup_segs}"
          module_id.split('/').each_with_object(lookup_segs) {|element, path|
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
      
      ctx.attach("#{JS_MOD}._loadSource", proc {|path, sourceURL=true|
        # For better error messages, we include the magic V8 sourceURL comment.
        # See https://bugs.chromium.org/p/v8/issues/detail?id=2948
        File.read(path) + (sourceURL ? "\n//# sourceURL=#{path}" : "")
      })
    end
  end
end

