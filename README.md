# ThreadRecycler
Recycle and reuse threads! 
Licensed under MIT (open-source)

## API

**⚠️ Using signals is not required for the thread to recycle correctly! Don't use it unless you're confident that callback(...) will yield (or pause) the script entirely. Misusing signals may result in unexpected behavior.**

### Using signals

```lua
local threads = require(module)
function(signal, ...)
signal:Fire() -- call when completed
end)

threads.defer(true, function, ...) -- can be threads.spawn and threads.wrap too
```

#### Using delay

**⚠️ This doesn't call task.delay due to multiple issues. Instead, coroutine.resume is called together with a heartbeat. **

```lua
threads.delay(true, time, function, ...)
```

### Not requiring signals

```lua
local threads = require(module)
function(...)
end)

threads.defer(false, function, ...) -- can be threads.spawn and threads.resume too
```

#### Using delay

```lua
threads.delay(false, time, function, ...)
```
