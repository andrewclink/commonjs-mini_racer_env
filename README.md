# CommonJS backed by MiniRacer

Host CommonJS JavaScript environments in Ruby via [MiniRacer](https://github.com/discourse/mini_racer)

This gem was ported from [commonjs.rb](https://github.com/cowboyd/commonjs.rb)

## Why?

The internet is now awash with non-browser JavaScript code. Much of this code conforms to some
simple conventions that let you use it anywhere you have a JavaScript interpreter available. These
conventions are collectively called "commonjs"

The MiniRacer interpreter allows us to evaluate JavaScript. Therefore, why shouldn't we be able to
use commonjs applications and libraries?

## Using common JS from Ruby.

`CommonJS::MiniRacerEnv` passes all of the Modules 1.0 unit tests.

```ruby
env = CommonJS::Environment.new(:path => '/path/to/lib/dir')
env.runtime.eval(%q|var foo = require('foo.js')|)
```

## Future directions

By default, all you get with a bare commonjs environment is the Modules API

The plan however, is to allow you to extend your commonjs environment to have whatever native
interfaces you want in it. So for example, if you want to allow filesystem access, as well as
access to the process information, you would say:

```ruby
env.modules :filesystem, :process
```

## Supported runtimes

Only MiniRacer is supported.
