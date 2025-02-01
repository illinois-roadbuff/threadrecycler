--!strict
--!native
-- Version 0.2.1-a.3
--@illinois_roadbuff

local Thread = {} -- Thread management
Thread.__index = Thread

type Thread = {
	useCallback: boolean, -- useCallback: Manual recycling?
	coroutineThread: thread, -- coroutineThread: Thread
}

type Recycler = { -- Recycler: Recycling pool
	threadCount: number, -- threadCount: Thread count
	availableThreads: {Thread}, -- availableThreads: Open threads
	nextIndex: number, -- nextIndex: Next index
	invokeCallback: () -> nil, -- invokeCallback: Call
	createThread: (boolean) -> Thread, -- createThread: Create thread
	yieldThread: () -> nil, -- yieldThread: Yield
	spawn:<T...> (boolean, (T...) -> nil, T...) -> nil,
	defer:<T...> (boolean, (T...) -> nil, T...) -> nil,
	wrap:<T...> (boolean, (T...) -> nil, T...) -> nil,
	delay:<T...> (boolean, number, (T...) -> nil, T...) -> nil
}

local recycler: Recycler = {} :: Recycler
setmetatable(recycler, Thread)

recycler.threadCount = 30 :: number -- negative = dynamic
recycler.availableThreads = {} :: {Thread}

local startWithSignal:boolean = true
local currentIndex:number = 1
local threadMetatable = {
	__index = function(thread, key:string)
		if key == "signal" then return thread.useCallback end
		if key == "coroutine" then return thread.coroutineThread end
		return rawget(thread, key)
	end
}

function Thread.recycle(index)
	local recycledThread:Thread = recycler.availableThreads[index]
	recycler.availableThreads[currentIndex] = recycledThread
	currentIndex += 1
end

function Thread._invoke<T...>(callback: (T...) -> nil, ...: T...)
	local availableThread:Thread = recycler.availableThreads[-1]
	if not availableThread then
		Thread._createThread(false)  
		availableThread = recycler.availableThreads[currentIndex - 1]
	end
	recycler.availableThreads[currentIndex - 1] = nil
	currentIndex -= 1

	if callback and (typeof(callback) == "table" or typeof(callback) == "function") then
		if availableThread.useCallback then
			callback(...)
		else
			callback(...)
			recycler.availableThreads[currentIndex] = availableThread
			currentIndex += 1
		end
	else
		warn(`ThreadRecycler: Invalid callback received: {typeof(callback)}. Is your callback a function?`)
	end
end

function Thread:_yield(closeThread: boolean)
	while not closeThread do
		Thread._invoke(coroutine.yield())
	end
end

function Thread._createThread(useSignal: boolean)
	local newThread: Thread | nil
	newThread = setmetatable({}, threadMetatable) :: Thread
	newThread.useCallback = useSignal
	newThread.coroutineThread = coroutine.create(recycler.yieldThread)
	coroutine.resume(newThread.coroutineThread, recycler)
	recycler.availableThreads[currentIndex] = newThread
	currentIndex += 1
end

function Thread.spawn<T...>(useSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #recycler.availableThreads < 1 then Thread._createThread(useSignal) end
	local availableThread:Thread = recycler.availableThreads[currentIndex - 1]
	local index = currentIndex - 1
	availableThread.useCallback = useSignal
	local status:string = coroutine.status(availableThread.coroutineThread)
	if status == "suspended" then
		if not useSignal then
			task.spawn(availableThread.coroutineThread, callback, ...)
		else
			task.spawn(availableThread.coroutineThread, callback, index, ...)
		end
	elseif status == "dead" then
		task.cancel(availableThread.coroutineThread)
		recycler.availableThreads[currentIndex - 1] = nil
		currentIndex -= 1
		Thread._createThread(useSignal)
		Thread.spawn(useSignal, callback, ...)
	end
end

function Thread.wrap<T...>(useSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #recycler.availableThreads < 1 then Thread._createThread(useSignal) end
	local availableThread:Thread = recycler.availableThreads[currentIndex - 1]
	local index = currentIndex - 1
	availableThread.useCallback = useSignal
	local status:string = coroutine.status(availableThread.coroutineThread)
	if status == "suspended" then
		if not useSignal then
			coroutine.resume(availableThread.coroutineThread, callback, ...)
		else
			coroutine.resume(availableThread.coroutineThread, callback, index, ...)
		end
	elseif status == "dead" then
		task.cancel(availableThread.coroutineThread)
		recycler.availableThreads[currentIndex - 1] = nil
		currentIndex -= 1
		Thread._createThread(useSignal)
		Thread.spawn(useSignal, callback, ...)
	end
end


function Thread.defer<T...>(useSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #recycler.availableThreads < 1 then Thread._createThread(useSignal) end
	local availableThread:Thread = recycler.availableThreads[currentIndex - 1]
	local index = currentIndex - 1
	availableThread.useCallback = useSignal
	local status:string = coroutine.status(availableThread.coroutineThread)
	if status == "suspended" then
		if not useSignal then
			task.wait()
			coroutine.resume(availableThread.coroutineThread, callback, ...)
		else
			task.wait()
			coroutine.resume(availableThread.coroutineThread, callback, index, ...)
		end
	elseif status == "dead" then
		task.cancel(availableThread.coroutineThread)
		recycler.availableThreads[currentIndex - 1] = nil
		currentIndex -= 1
		Thread._createThread(useSignal)
		Thread.spawn(useSignal, callback, ...)
	end
end

function Thread.delay<T...>(useSignal:boolean, time:number, callback: (T...) -> nil, ...: T...)
	if #recycler.availableThreads < 1 then Thread._createThread(useSignal) end
	local availableThread:Thread = recycler.availableThreads[currentIndex - 1]
	local index = currentIndex - 1
	availableThread.useCallback = useSignal
	local status:string = coroutine.status(availableThread.coroutineThread)
	if status == "suspended" then
		if not useSignal then
			task.wait(time)
			coroutine.resume(availableThread.coroutineThread, callback, ...)
		else
			task.wait(time)
			coroutine.resume(availableThread.coroutineThread, callback, index, ...)
		end
	elseif status == "dead" then
		task.cancel(availableThread.coroutineThread)
		recycler.availableThreads[currentIndex - 1] = nil
		currentIndex -= 1
		Thread._createThread(useSignal)
		Thread.spawn(useSignal, callback, ...)
	end
end

for n = 1, math.abs(recycler.threadCount), 1 do
	Thread._createThread(startWithSignal)
end
return Thread



