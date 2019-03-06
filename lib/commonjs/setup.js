class Module {
  constructor(id) {
    this._id = id;
    this._segments = id.split("/");
    this.exports = {};
  }
  get id() { return this._id; }

  require(modId) {
    let klass = this.constructor;
    console.log('====================================')
    console.log(`require(${modId}:${typeof modId}) (from ${this._id})`)
    
    // Support remapping 
    if (Module.esmRemap.hasOwnProperty(modId) && Module.esmRemap[modId]) {
      modId = Module.esmRemap[modId];
    }

    // Check for ruby module
    if (klass._cache['*' + modId])
      return klass._cache['*' + modId].exports
      
    // Do not use `modId` after this line; use `expandedId`
    console.log("_findPackage id, segments, moduleId:", this._id, this._segments, modId)
    let {id, path} = klass._findPackage(__commonjs__.loadPaths, this._id, this._segments, modId);
    console.log("_findPackage returned", id, path)

    let mod = klass._cache[id];
    if (!mod) {
      console.log(`Cache['${id}'] miss; loading from ${path}` )
      let loader = (module, require, exports) => { 
        if (path.indexOf('.json') == path.length-5) {
          const src = klass._loadSource(path, false);
          // console.log("Loading JSON", path);
          module.exports = JSON.parse(src);
        }
        else {
          console.log("eval source", path);
          eval(klass._loadSource(path)); 
        }
        console.success("Loaded OK", module._id);
      };

      // must be cached before loading, in case there are circular deps
      console.success("Caching module as", id);
      klass._cache[id] = mod = new klass(id);
      loader(mod, mod.require.bind(mod), mod.exports);
    }
    else {
      console.success(`Cache['${id}'] HIT` )
    }
    return mod.exports;
  }
}

Module.esmRemap = {
  'stream' : 'readable-stream',
  './internal/streams/stream': './internal/streams/stream-browser'
}

// Install top-level `require` function (on global object like Node)
this.require = (() => {
  let topMod = new Module('topMod');  // let this go out of scope
  return topMod.require.bind(topMod);
})();