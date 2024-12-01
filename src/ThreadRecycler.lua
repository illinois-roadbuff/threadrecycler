--!strict
--!native


-- Version 0.1.0-a.2

--@illinois_roadbuff

--[[
API:
local threads = require(module)
function(signal, ...)
signal:Fire() -- call when completed
end)

threads.defer(function, ...) -can be threads.spawn too


]]

local GoodSignal = require(script.GoodSignal) -- require good signal or fast signal or random

local IRBThread = {}
IRBThread.__index = IRBThread

local threadPoolInstance  = {}

setmetatable(threadPoolInstance, IRBThread)

threadPoolInstance._openThreads = {}
threadPoolInstance._threadCount = -30 --negative = dynamic
threadPoolInstance._cachedThreadLifetime =  60 :: number?

print("initiated!!!!!")

local RelyOnCallback = false -- must be false
local RelyOnSignal = true -- must be true

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

function IRBThread._call<T...>(callback: (T...) -> nil, ...: T...)
	local index = #threadPoolInstance._openThreads
	local thread = threadPoolInstance._openThreads[index]
	threadPoolInstance._openThreads[index] = nil
	print("Recycling thread. Remaining open threads: " .. tostring(#threadPoolInstance._openThreads))
	warn("Called!")
	if callback and typeof(callback) == "table" or typeof(callback) == "function" then
		if RelyOnCallback then
			callback(...)
			table.insert(threadPoolInstance._openThreads, thread) 
			warn("C: Recycled thread added back. Total threads now: " .. tostring(#threadPoolInstance._openThreads))
		elseif RelyOnSignal then
			--local Signal = GoodSignal.new()
			--task.spawn(callback, ...)
			thread._signal:Connect(function()
				table.insert(threadPoolInstance._openThreads, thread) 
				warn("S: Recycled thread added back. Total threads now: " .. tostring(#threadPoolInstance._openThreads))
			end)
			
			callback(...)
		--	thread._signal:Wait()
				
			
			--thread._signalSignal:Disconnect
		end
	end


end

function IRBThread:_yield(closeThread: boolean): nil
	while not closeThread do
		threadPoolInstance._call(coroutine.yield())
	end

	return 
end

function IRBThread._createThread()
	local newThread: thread | nil
	local threadSignal = GoodSignal.new()

	newThread = setmetatable({}, threadMetatable)  

	-- Attach the signal to the thread
	newThread._signal = threadSignal  




	newThread._coroutine = coroutine.create(threadPoolInstance._yield)
	if #threadPoolInstance._openThreads > threadPoolInstance._threadCount then
		local index = #threadPoolInstance._openThreads + 1

		task.delay(threadPoolInstance._cachedThreadLifetime, function()
			newThread = nil
			threadPoolInstance._openThreads[index] = nil
			print("Thread recycled. Current open threads: " .. tostring(#threadPoolInstance._openThreads))
		end)
	end
	coroutine.resume(newThread._coroutine :: thread, threadPoolInstance)
	table.insert(threadPoolInstance._openThreads, newThread)
	print("Created new thread. Total threads now: " .. tostring(#threadPoolInstance._openThreads))
end

function IRBThread.spawn<T...>(callback: (T...) -> nil, ...: T...)
	if #threadPoolInstance._openThreads < 1 then
		print("No available threads. Creating a new one.")
		threadPoolInstance._createThread()
	end
	local thread = threadPoolInstance._openThreads[#threadPoolInstance._openThreads] 
	if thread and thread._coroutine then
		if  coroutine.status(thread._coroutine) == "suspended" then
			print("Spawning new task on thread. Total threads now: " .. tostring(#threadPoolInstance._openThreads))
			if RelyOnCallback then
				task.spawn(thread._coroutine, callback, ...)
			elseif RelyOnSignal then
				--local Signal = GoodSignal.new()
				task.spawn(thread._coroutine, callback, thread._signal, ...)
				--	Signal:Wait()
				--	Signal:DisconnectAll()
			end
		elseif  coroutine.status(thread._coroutine) == "dead" then
			print("Thread is dead, creating a new thread.")
			task.cancel(thread._coroutine)
			table.remove(threadPoolInstance._openThreads, #threadPoolInstance._openThreads)

			threadPoolInstance._createThread()
			threadPoolInstance.spawn(callback, ...) 
		elseif  coroutine.status(thread._coroutine) ~= "running" or  coroutine.status(thread._coroutine) ~= "normal" then
			warn("unexpected?"..coroutine.status(thread._coroutine))
		end
	else
		warn("thread is nil")
	end
end

function IRBThread.resume<T...>(callback: (T...) -> nil, ...: T...)
	if #threadPoolInstance._openThreads < 1 then
		print("No available threads. Creating a new one.")
		threadPoolInstance._createThread()
	end
	local thread = threadPoolInstance._openThreads[#threadPoolInstance._openThreads] 
	if thread and thread._coroutine then
		if  coroutine.status(thread._coroutine) == "suspended" then
			print("Spawning new task on thread. Total threads now: " .. tostring(#threadPoolInstance._openThreads))
			if RelyOnCallback then
				--task.spawn(thread._coroutine, callback, ...)
				coroutine.resume(thread._coroutine, callback, ...)
			elseif RelyOnSignal then
				--local Signal = GoodSignal.new()
				coroutine.resume(thread._coroutine, callback, thread._signal, ...) 
				--	Signal:Wait()
				--	Signal:DisconnectAll()
			end
		elseif  coroutine.status(thread._coroutine) == "dead" then
			print("Thread is dead, creating a new thread.")
			task.cancel(thread._coroutine)
			table.remove(threadPoolInstance._openThreads, #threadPoolInstance._openThreads)

			threadPoolInstance._createThread()
			threadPoolInstance.resume(callback, ...) 
		elseif  coroutine.status(thread._coroutine) ~= "running" or  coroutine.status(thread._coroutine) ~= "normal" then
			warn("unexpected?"..coroutine.status(thread._coroutine))
		end
	else
		warn("thread is nil")
	end
end

function IRBThread.defer<T...>(callback: (T...) -> nil, ...: T...)
	if #threadPoolInstance._openThreads < 1 then
		print("No available threads. Creating a new one.")
		threadPoolInstance._createThread()
	end
	local thread = threadPoolInstance._openThreads[#threadPoolInstance._openThreads] 
	if thread and thread._coroutine then
		if  coroutine.status(thread._coroutine) == "suspended" then
			if RelyOnCallback then

				game["Run Service"].Heartbeat:Wait()
			--	task.spawn(thread, callback, ...)
				coroutine.resume(thread._coroutine, callback, ...)
			elseif RelyOnSignal then
				--local Signal = GoodSignal.new()


				game["Run Service"].Heartbeat:Wait()
			--	task.spawn(thread._coroutine, callback, thread._signal, ...)
				coroutine.resume(thread._coroutine, callback, thread._signal, ...)
			--	Signal:Wait()
			--	Signal:DisconnectAll()
			end
		elseif  coroutine.status(thread._coroutine) == "dead" then
			print("Thread is dead, creating a new thread.")
			task.cancel(thread._coroutine)
			table.remove(threadPoolInstance._openThreads, #threadPoolInstance._openThreads)

			threadPoolInstance._createThread()
			threadPoolInstance.defer(callback, ...)
		elseif  coroutine.status(thread._coroutine) ~= "running" or  coroutine.status(thread._coroutine) ~= "normal" then
			warn("unexpected?"..coroutine.status(thread._coroutine))
		end
	else
		warn("thread is nil")
	end
end

function IRBThread.delay<T...>(t:number, callback: (T...) -> nil, ...: T...)
	if #threadPoolInstance._openThreads < 1 then
		print("No available threads. Creating a new one.")
		threadPoolInstance._createThread()
	end
	local thread = threadPoolInstance._openThreads[#threadPoolInstance._openThreads] 
	if thread and thread._coroutine then
		if  coroutine.status(thread._coroutine) == "suspended" then
			if RelyOnCallback then

			--	game["Run Service"].Heartbeat:Wait()
				--	task.spawn(thread, callback, ...)
				--coroutine.resume(thread._coroutine, callback, ...)
				task.delay(t, thread._coroutine, callback, ...)
			elseif RelyOnSignal then
				--local Signal = GoodSignal.new()


			--	game["Run Service"].Heartbeat:Wait()
				--	task.spawn(thread._coroutine, callback, thread._signal, ...)
				--coroutine.resume(thread._coroutine, callback, thread._signal, ...)
				task.delay(t, thread._coroutine, callback, thread._signal, ...)
				--	Signal:Wait()
				--	Signal:DisconnectAll()
			end
		elseif  coroutine.status(thread._coroutine) == "dead" then
			print("Thread is dead, creating a new thread.")
			task.cancel(thread._coroutine)
			table.remove(threadPoolInstance._openThreads, #threadPoolInstance._openThreads)

			threadPoolInstance._createThread()
			threadPoolInstance.delay(t, callback, ...)
		elseif  coroutine.status(thread._coroutine) ~= "running" or  coroutine.status(thread._coroutine) ~= "normal" then
			warn("unexpected?"..coroutine.status(thread._coroutine))
		end
	else
		warn("thread is nil")
	end
end

function IRBThread.new(threadCount: number?, cachedThreadLifetime: number?)
	return threadPoolInstance
end

for n = 1, math.abs(threadPoolInstance._threadCount), 1 do
	IRBThread._createThread()
	print("Initial thread created. Total threads now: " .. tostring(#threadPoolInstance._openThreads))
end

export type IRBThread = typeof(IRBThread.new())

return IRBThread
