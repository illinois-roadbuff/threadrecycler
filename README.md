# ThreadRecycler
Recycle and reuse threads!

## API

**⚠️ Using signals is not required for the thread to recycle correctly! Don't use it unless you're confident that callback(...) will yield (or pause) the script entirely (forever).**

### Using signals

local threads = require(module)

function(signal, ...)

signal:Fire() -- call when completed

end)

threads.defer(true, function, ...) -- can be threads.spawn and threads.resume too

#### Delay

threads.delay(true, time, function, ...)

### Not using signals

local threads = require(module)

function(...)

end)

threads.defer(false, function, ...) -- can be threads.spawn and threads.resume too

#### Delay

threads.delay(false, time, function, ...)
