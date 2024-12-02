# ThreadRecycler
Recycle and reuse threads!

## API
local threads = require(module)

function(signal, ...)

signal:Fire() -- call when completed

end)

threads.defer(function, ...) -- can be threads.spawn and threads.resume too

### Delay

threads.delay(time, function, ...)
