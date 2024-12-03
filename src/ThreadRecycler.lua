--!strict
--!native

-- Version 0.2.0-a.1

--@illinois_roadbuff

--[[
⚠️ Using signals is not required for the thread to recycle correctly! Don't use it unless you're confident that callback(...) will yield (or pause) the script entirely.

API (using signal):
local threads = require(module)
function(index, ...)
threads._addrecycled(index) -- call when completed
end)

threads.defer(true, function, ...) -can be threads.spawn too

API (not using signal):
local threads = require(module)
function(...)

end)

threads.defer(false, function, ...) -can be threads.spawn too

]]

--local GoodSignal = require(script.FastSignal) -- require good signal or fast signal or random

local IRBThread = {} 
IRBThread.__index = IRBThread

local threadPoolInstance  = {} 

setmetatable(threadPoolInstance, IRBThread)

threadPoolInstance._openThreads = {} 
threadPoolInstance._threadCount = 30 :: number --negative = dynamic
threadPoolInstance._cachedThreadLifetime =  60 :: number?

--print("initiated!!!!!")

--local RelyOnCallback = false -- must be false
local StartOnSignal:boolean = true

local nextThreadIndex:number = 1



local threadMetatable = {
	__index = function(thread, key)
		if key == "signal" then

			return thread._signal
		end
		if key == "coroutine" then

			return thread._coroutine
		end

		return rawget(thread, key)
	end
}

function IRBThread._getThread() 
	nextThreadIndex = #threadPoolInstance._openThreads 
	local thread:thread? = threadPoolInstance._openThreads[nextThreadIndex]

	return thread, nextThreadIndex
end

function IRBThread._addThread(thread)
	threadPoolInstance._openThreads[#threadPoolInstance._openThreads + 1] = thread
	nextThreadIndex = #threadPoolInstance._openThreads 
end


function IRBThread._releaseThread()
	threadPoolInstance._openThreads[#threadPoolInstance._openThreads] = nil
	nextThreadIndex = #threadPoolInstance._openThreads 
end

function IRBThread._addrecycled(index)
	local thread:thread? = threadPoolInstance._openThreads[index]
	IRBThread._addThread(thread)
end

function IRBThread._call<T...>(callback: (T...) -> nil, ...: T...)

	local thread, index = IRBThread._getThread() 
	if not thread then
		thread = IRBThread._createThread(true)  
	end

	IRBThread._releaseThread()

	if callback and typeof(callback) == "table" or typeof(callback) == "function" then
		if thread._signal then
			callback(...)
			--warn("C: Recycled thread added back. Total threads now: " .. tostring(#threadPoolInstance._openThreads).." "..nextThreadIndex)
		else
			callback(...)
			IRBThread._addThread(thread)
		end
	else
		print(typeof(callback))
	end
end
function IRBThread:_yield(closeThread: boolean): nil
	while not closeThread do
		threadPoolInstance._call(coroutine.yield())
	end
	return 
end

function IRBThread._createThread(UseSignal: boolean)
	local newThread: thread | nil

	newThread = setmetatable({}, threadMetatable)  

	newThread._signal = UseSignal
	newThread._coroutine = coroutine.create(threadPoolInstance._yield)
	coroutine.resume(newThread._coroutine :: thread, threadPoolInstance)
	IRBThread._addThread(newThread)
end

function IRBThread.spawn<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #threadPoolInstance._openThreads < 1 then
		threadPoolInstance._createThread(UseSignal)
	end
	local thread, index = IRBThread._getThread()

	if thread and thread._coroutine then
		if  coroutine.status(thread._coroutine) == "suspended" then
			if not UseSignal then
				task.spawn(thread._coroutine, callback, ...)
			else
				task.spawn(thread._coroutine, callback, index, ...)
			end
		elseif  coroutine.status(thread._coroutine) == "dead" then
			task.cancel(thread._coroutine)
			IRBThread._releaseThread()

			threadPoolInstance._createThread(UseSignal)
			threadPoolInstance.spawn(UseSignal, callback, ...) 
		elseif  coroutine.status(thread._coroutine) ~= "running" or  coroutine.status(thread._coroutine) ~= "normal" then
				warn("unexpected?"..coroutine.status(thread._coroutine))
		end
	else
		warn("thread is nil")
	end
end

function IRBThread.wrap<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #threadPoolInstance._openThreads < 1 then
		threadPoolInstance._createThread(UseSignal)
	end
	local thread, index = IRBThread._getThread()
	if thread and thread._coroutine then
		local status = coroutine.status(thread._coroutine)
		if  status == "suspended" then
			if not UseSignal then
				coroutine.resume(thread._coroutine, callback, ...)
			else
				coroutine.resume(thread._coroutine, callback, index, ...) 
			end
		elseif  status == "dead" then
			task.cancel(thread._coroutine)
			IRBThread._releaseThread(thread)

			threadPoolInstance._createThread(UseSignal)
			threadPoolInstance.wrap(UseSignal, callback, ...) 
		elseif  status ~= "running" and  status ~= "normal" then
				warn("unexpected?"..coroutine.status(thread._coroutine))
		end
	else
			warn("thread is nil")
	end
end

function IRBThread.defer<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #threadPoolInstance._openThreads < 1 then

		threadPoolInstance._createThread(UseSignal)
	end

	local thread, index = IRBThread._getThread()
	if thread and thread._coroutine then
		local status = coroutine.status(thread._coroutine)
		if  status == "suspended" then
			if not UseSignal then
				game["Run Service"].Heartbeat:Wait()

				coroutine.resume(thread._coroutine, callback, ...)
			else
	


				game["Run Service"].Heartbeat:Wait()
	
				coroutine.resume(thread._coroutine, callback, index, ...)

			end
		elseif  status == "dead" then

			task.cancel(thread._coroutine)

			IRBThread._releaseThread(thread)

			threadPoolInstance._createThread(UseSignal)
			threadPoolInstance.defer(UseSignal, callback, ...)
	--	elseif  status ~= "running" and status ~= "normal" then
		--	warn("unexpected?"..coroutine.status(thread._coroutine))
		end
	else
			warn("thread is nil")
	end
end

function IRBThread.delay<T...>(UseSignal, t:number, callback: (T...) -> nil, ...: T...)
	if #threadPoolInstance._openThreads < 1 then
		print("No available threads. Creating a new one.")
		threadPoolInstance._createThread(UseSignal)
	end
	local thread, index = IRBThread._getThread()
	if thread and thread._coroutine then
		local status = coroutine.status(thread._coroutine)
		if  status == "suspended" then
			if not UseSignal then
				task.delay(t, thread._coroutine, callback, ...)
			else
				task.delay(t, thread._coroutine, callback, index, ...)
			end
		elseif  status == "dead" then
			--	print("Thread is dead, creating a new thread.")
			task.cancel(thread._coroutine)
			--	table.remove(threadPoolInstance._openThreads, #threadPoolInstance._openThreads)
			IRBThread._releaseThread(thread)

			threadPoolInstance._createThread(UseSignal)
			threadPoolInstance.delay(UseSignal, t, callback, ...)
		elseif  status ~= "running" and  status ~= "normal" then
			--	warn("unexpected?"..coroutine.status(thread._coroutine))
		end
	else
		--warn("thread is nil")
	end
end

function IRBThread.new(threadCount: number?, cachedThreadLifetime: number?)
	return threadPoolInstance
end

for n = 1, math.abs(threadPoolInstance._threadCount), 1 do
	IRBThread._createThread(StartOnSignal)
	--print("Initial thread created. Total threads now: " .. tostring(#threadPoolInstance._openThreads))
end



export type IRBThread = typeof(IRBThread.new())

return IRBThread
