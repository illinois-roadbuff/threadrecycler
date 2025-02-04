--!strict
--!native
-- Version 0.2.2-a.3
--@Illinois_Roadbuff

-- // Thread Recycler; Recycle and reuse threads!

local RunService = game:GetService("RunService")

local threads = {} -- t: Threads
threads.__index = threads

type threads = {
	_call: boolean, -- _c: Callback? (Manual recycling?)
	_thread: thread, -- _t: Thread
}

local recycler = {} 
recycler.__index = recycler

local ThreadStatsEnabled = true

local ThreadStats = {
	["Recycled"] = 0,
	["Created"] = 0,
	["Count"] = 0,
}

export type recycler = { -- r: Recycling pool?
	_tcount: number, -- Thread count
	_open: {threads}, -- _o: Open threads
	_invoke: () -> nil, -- _c: Call
	_create: (boolean) -> threads, -- _n: Create thread
	_yield: () -> nil, -- _y: Yield
	spawn:<T...> (boolean, (T...) -> nil, T...) -> nil,
	defer:<T...> (boolean, (T...) -> nil, T...) -> nil,
	gooddefer:<T...> (boolean, (T...) -> nil, T...) -> nil,
	unsafedefer:<T...> (boolean, (T...) -> nil, T...) -> nil,
	wrap:<T...> (boolean, (T...) -> nil, T...) -> nil,
	delay:<T...> (boolean, number,  (T...) -> nil, T...) -> nil,
	unsafedelay:<T...> (boolean, number,  (T...) -> nil, T...) -> nil,
	wait: (number | nil) -> nil,
	recycle: (number) -> nil,
	getstat: (string) -> boolean, result:number | string
}

setmetatable(recycler::recycler, threads)

recycler._tcount = 30 :: number --negative = dynamic
recycler._open = {} :: {threads}

local StartOnSignal:boolean = true :: boolean

local threadMetatable = {
	__index = function(thread, key:string)
		if key == "call" then	return thread._call end
		if key == "thread" then return thread._thread end
		return rawget(thread, key)
	end
}

function recycler.getstat(index: string)
	if ThreadStats then
	ThreadStats.Count = #recycler._open
		local stat = ThreadStats[index]
		if stat then
			return true, stat
		else
			local warning = "ThreadRecycler: getstat called with invalid argument. Does this 'stat' exist? Only: Recycled; Created; Count"
			warn(warning)
			return false, warning
		end
	else
		local warning = "ThreadRecycler: getstat called while ThreadStats are disabled. Prevent this by opening this module and changing the configuration."
		warn(warning)
		return false, warning
	end
end

function recycler.recycle(index: number)
	local thread:threads = recycler._open[index]
	recycler._open[#recycler._open + 1] = thread
	if ThreadStats then
		ThreadStats.Recycled += 1
	end
end

function recycler.wait(seconds: number | nil)
	local startTime = os.clock()
	while os.clock() - startTime < (if seconds then seconds else RunService.Heartbeat:Wait()) do
		RunService.Heartbeat:Wait()
	end
end

function recycler._invoke<T...>(callback: (T...) -> nil, ...: T...)
	local thread:threads? = table.remove(recycler._open, #recycler._open) -- Get the last thread
	if not thread then
		recycler._create(false)  
		thread = table.remove(recycler._open, #recycler._open)
	end

	if  thread == nil then warn("ThreadRecycler: Thread is nil.") end
	if  thread and thread._call == nil then warn("ThreadRecycler: Callback is nil.") end

	if callback and typeof(callback) == "table" or typeof(callback) == "function" then
		if thread and thread._call then callback(...) else callback(...)
			recycler._open[#recycler._open + 1] = thread :: threads
			if ThreadStats then
				ThreadStats.Recycled += 1
			end
		end
	else warn(`ThreadRecycler: Invalid callback recived: {typeof(callback)}. Is your callback a function?`) end
end

function recycler:_yield(closeThread: boolean)
	while not closeThread do
		recycler._invoke(coroutine.yield())
	end
end

function recycler._create(UseSignal: boolean)
	local newThread: threads | nil
	newThread = setmetatable({}, threadMetatable) :: threads

	newThread._call = UseSignal :: boolean
	newThread._thread = coroutine.create(recycler._yield) :: thread
	coroutine.resume(newThread._thread :: thread, recycler :: recycler)
	recycler._open[#recycler._open + 1] = newThread
	if ThreadStats then
		ThreadStats.Created += 1
	end
end

function recycler.spawn<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #recycler._open < 1 then recycler._create(UseSignal) end
	local thread:threads? = table.remove(recycler._open, #recycler._open)
	local index = #recycler._open + 1
	if thread then
		thread._call = UseSignal
		local status:string = coroutine.status(thread._thread)
		if  status == "suspended" then
			if not UseSignal then
				task.spawn(thread._thread::thread, callback:: (T...) -> nil, ...)
			else
				task.spawn(thread._thread::thread, callback:: (T...) -> nil, index::number, ...)
			end
		elseif  status == "dead" then
			task.cancel(thread._thread)
			recycler._create(UseSignal)
			recycler.spawn(UseSignal, callback, ...) 
		end
	else
		warn("ThreadRecycler: Thread is nil.")
	end
end

function recycler.wrap<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #recycler._open < 1 then recycler._create(UseSignal) end
	local thread:threads? = table.remove(recycler._open, #recycler._open)
	local index = #recycler._open + 1
	if thread then
		thread._call = UseSignal
		local status:string = coroutine.status(thread._thread)
		if  status == "suspended" then
			if not UseSignal then
				coroutine.resume(thread._thread::thread, callback:: (T...) -> nil, ...)
			else
				coroutine.resume(thread._thread::thread, callback:: (T...) -> nil, index::number, ...)
			end
		elseif  status == "dead" then
			recycler._create(UseSignal)
			recycler.wrap(UseSignal, callback, ...) 
		end
	else
		warn("ThreadRecycler: Thread is nil.")
	end
end

function recycler.defer<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #recycler._open < 1 then recycler._create(UseSignal) end
	local thread:threads? = table.remove(recycler._open, #recycler._open)
	local index = #recycler._open + 1
	if thread then
		thread._call = UseSignal
		local status:string = coroutine.status(thread._thread)
		if  status == "suspended" then
			if not UseSignal then
				recycler.wait()--task.wait()
				coroutine.resume(thread._thread::thread, callback:: (T...) -> nil, ...)
			else
				recycler.wait()--task.wait()
				coroutine.resume(thread._thread::thread, callback:: (T...) -> nil, index::number, ...)
			end
		elseif  status == "dead" then
			recycler._create(UseSignal)
			recycler.defer(UseSignal, callback, ...)
		end
	else
		warn("ThreadRecycler: Thread is nil.")
	end
end

function recycler.gooddefer<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #recycler._open < 1 then recycler._create(UseSignal) end
	local thread:threads? = table.remove(recycler._open, #recycler._open)
	local index = #recycler._open + 1
	if thread then
		thread._call = UseSignal
		local status:string = coroutine.status(thread._thread)
		if  status == "suspended" then
			if not UseSignal then
				RunService.Heartbeat:Wait()
				coroutine.resume(thread._thread::thread, callback:: (T...) -> nil, ...)
			else
				RunService.Heartbeat:Wait()
				coroutine.resume(thread._thread::thread, callback:: (T...) -> nil, index::number, ...)
			end
		elseif  status == "dead" then
			recycler._create(UseSignal)
			recycler.gooddefer(UseSignal, callback, ...)
		end
	else
		warn("ThreadRecycler: Thread is nil.")
	end
end

function recycler.unsafedefer<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #recycler._open < 1 then recycler._create(UseSignal) end
	local thread:threads? = table.remove(recycler._open, #recycler._open)
	local index = #recycler._open + 1
	if thread then
		thread._call = UseSignal
		local status:string = coroutine.status(thread._thread)
		if  status == "suspended" then
			if not UseSignal then
				task.defer(thread._thread::thread, callback:: (T...) -> nil, ...)
			else
				task.defer(thread._thread::thread, callback:: (T...) -> nil, index::number, ...)
			end
		elseif  status == "dead" then
			recycler._create(UseSignal)
			recycler.unsafedefer(UseSignal, callback, ...)
		end
	else
		warn("ThreadRecycler: Thread is nil.")
	end
end

function recycler.delay<T...>(UseSignal, time:number, callback: (T...) -> nil, ...: T...)
	if #recycler._open < 1 then recycler._create(UseSignal) end
	local thread:threads? = table.remove(recycler._open, #recycler._open)
	local index = #recycler._open + 1
	if thread then
		thread._call = UseSignal
		local status:string = coroutine.status(thread._thread)
		if  status == "suspended" then
			if not UseSignal then
				recycler.wait(time)--task.wait(time)
				coroutine.resume(thread._thread::thread, callback:: (T...) -> nil, ...)
			else
				recycler.wait(time)--task.wait(time)
				coroutine.resume(thread._thread::thread, callback:: (T...) -> nil, index::number, ...)
			end
		elseif  status == "dead" then
			recycler._create(UseSignal)
			recycler.delay(UseSignal, time, callback, ...)
		end
	else
		warn("ThreadRecycler: Thread is nil.")
	end
end

function recycler.unsafedelay<T...>(UseSignal, time:number, callback: (T...) -> nil, ...: T...)
	if #recycler._open < 1 then recycler._create(UseSignal) end
	local thread:threads? = table.remove(recycler._open, #recycler._open)
	local index = #recycler._open + 1
	if thread then
		thread._call = UseSignal
		local status:string = coroutine.status(thread._thread)
		if  status == "suspended" then
			if not UseSignal then
				task.delay(time, thread._thread::thread, callback:: (T...) -> nil, ...)
			else
				task.delay(time, thread._thread::thread, callback:: (T...) -> nil, index::number, ...)
			end
		elseif  status == "dead" then
			recycler._create(UseSignal)
			recycler.unsafedelay(UseSignal, time, callback, ...)
		end
	else
		warn("ThreadRecycler: Thread is nil.")
	end
end

for n = 1, math.abs(recycler._tcount), 1 do
	recycler._create(StartOnSignal)
end

return recycler
