# MiniRacer Usage Tips

MiniRacer isn't as "powerful" as therubyracer. This is a list of some "limitations" that you'll need to work around when porting code to use MiniRacer.

- Only basic values can be passed between JS & ruby: bools, numbers, strings, array, hash (array/hash can be nested arbitrarily)

- Cannot pass arbitrary ruby objects, or even functions (contrast w/ therubyracer which can pass arbitrary objects from JS to ruby & vice versa)

- There is auto-conversion between ruby `Time` & JS `Date` in certain cases:
  - OK: Non-nested ruby `Time`s & JS `Date`s are converted.
  - OK: `Time`s in nested ruby objects (e.g. `{a: [Time.now]}`) are converted.
  - NOT-OK: `Date`s in nested JS objects (e.g. `{a: new Date()}`) become strings. See https://github.com/discourse/mini_racer/issues/121

- A ruby callback can be `attach`ed to a JS variable (can be a nested name like `mod.func`, in which case the nesting parents will be auto-vivified) and will appear in JS as a regular function.

- When attaching a ruby proc to a JS property on a JS object (e.g. `mod.func`), the object will not be passed as the first arg to the proc (i.e. `this` reference); only the args to the function will be passed. This differs from therubyracer, which does pass `this`.

- `Context#call` seems to require a top-level function that's a property of the global object
  - calling a function nested in an object (e.g. 'foo.bar') won't work
  - calling a top-level function defined via `let` won't work

# MiniRacer Function-Attaching Tips

## Performance

The following benchmark comparisons were done on a 2016 MacBook Pro using ruby 2.3.6 and MiniRacer 0.2.4.

Apparently, an attached proc is actually a tiny bit faster than an attached method (~ 2 microsec per iteration). It's not clear whether the reverse would be true if the proc captured a larger set of variables from the surrounding scope.

The native JS function is the fastest (as expected), but not by much (~ 8 microsec); but benchmarks may become less reliable with increasing complexity of logic.

```ruby
module AttachTest
  def self.a_method(a); a + 1; end
end
# Compare attaching a `proc` vs a `Method`
def test_attach_perf
  require 'benchmark'
  pr = proc {|a| a + 1 }
  ctx = new_ctx
  ctx.attach('aProc', pr)
  ctx.attach('aMethod', AttachTest.method(:a_method))
  ctx.eval('nativeFunc = (a) => { return a + 1; }')

  iters = 10_000
  Benchmark.bmbm do |b|
    b.report('aProc') { iters.times { ctx.call('aProc', 501) } }            # middle
    b.report('aMethod') { iters.times { ctx.call('aMethod', 501) } }        # slowest
    b.report('nativeFunc') { iters.times { ctx.call('nativeFunc', 501) } }  # fastest
  end
end
```

## Argument-Count Forgiveness

When choosing between a `proc`, a `lambda`, or a `Method` object, also consider that javascript functions are very forgiving in that they allow fewer or more arguments than in the function signature, without throwing an error.

`proc`s automatically give you the same behavior (instead of `raise`ing an `ArgumentError`). You could handle the "more arguments" scenario with `lambda`s & `Method`s by including a splatted final argument to "slurp" up the extras (e.g. `def func(a, *b) ...`), but that's cumbersome. Which one you choose depends on whether you want the function to be forgiving.
