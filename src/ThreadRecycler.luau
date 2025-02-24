--!native
--!strict

--[[-{Standalone Version}-[ThreadRecycler]---------------------------------------
  FILE:             ThreadRecycler.luau
  DESCRIPTION:      Recycle and reuse threads via thread pooling!
  USAGE:            ./ThreadRecycler.luau
  PREREQUISITES:    None (Dependencies)
  LANGUAGE:         Luau
  FRAMEWORK:        N/A (Standalone Version)
  
  AUTHOR:           Illinois_Roadbuff
  VERSION:          0.3.1-alpha.1
  CREATED:          2024-11-29 10:47 AM CST  
  LAST UPDATE:      2025-2-23 11:16 PM CST  
  LICENSE:          MIT License

  GITHUB REPO:      https://github.com/illinois-roadbuff/threadrecycler
  DOCS:             https://illinois-roadbuff.github.io/threadrecycler/docs
  DEVFORUM:         https://devforum.roblox.com/t/3445032/2
------------------------------------------------------------------------------]]  

--// ----- Module Table ----- //--

local recycler:recycler = {
} :: recycler

--// ----- Constants ----- //--

local SETTINGS = {
	Default = {
		threadCount = 10 :: number, -- Default initial thread count 
		cachedtime = false :: number | boolean, -- Default cached lifetime 
		enableStatRecording = false :: boolean, -- Enables default recording of stats 
		logger = warn :: () -> () , -- Default log method; doesn't do anything right now. Coming in the future... 
		debug = false :: boolean, -- Default debug configuration. Doesn't do anything right now. Coming in the future... 
	}
}

--// ----- Private Variables ----- //--

local RunService:RunService = game.GetService(game, "RunService") :: RunService -- Shhh, a lot faster :) 

local GlobalPool:recycler

export type recycler = { -- Recycling pool?
	__index: () -> () | recycler,
	construct: ({InitialThreadCount:number, CachedLifetime:number|boolean, EnableStatRecording:boolean, Logger:()->(), Debug:boolean}) -> recycler,
	_tcount: number, -- Thread count
	_enablestatrec: boolean,
	_debug: boolean,
	_logger: () -> (),
	_open: {thread}, --  Open threads
	_invoke: <T...> (recycler, thread, (thread, T...) -> nil, T...) -> (), --  Call
	_create: (recycler) -> (), --  Create thread
	_yield: (recycler, boolean) -> (), --  Yield
	_time: number | boolean,
	spawn:<T...> (recycler? | boolean, (T...) -> nil, T...) -> thread,
	defer:<T...> (recycler? | boolean, (T...) -> nil, T...) -> boolean,
	gooddefer:<T...> (recycler? | boolean, (T...) -> nil, T...) -> boolean,
	unsafedefer:<T...> (recycler? | boolean, (T...) -> nil, T...) -> thread,
	wrap:<T...> (recycler? | boolean, (T...) -> nil, T...) -> boolean,
	autocompatible:<T...> (recycler, (T...) -> nil, T...) -> boolean,
	delay:<T...> (recycler? | boolean, number,  (T...) -> nil, T...) -> boolean,
	unsafedelay:<T...> (recycler? | boolean, number,  (T...) -> nil, T...) -> thread,
	wait: (number?) -> (),
	recycle: (recycler, thread) -> (),
	getstat: (recycler, string) -> boolean, result:number | string,
	ThreadStats: {Created:number, Count:number, Recycled:number},
}
recycler.__index = recycler 

--// ----- Private Functions ----- //--

local function SetUpRecycler(local_recycler:recycler, Config:{})
	if Config["InitialThreadCount"] == nil or Config["CachedLifetime"] == nil then warn("ThreadRecycler: Warning; do you have a configuration? .new({['ThreadCount'] = 0, ['CachedLifetime'] = false})") end
	local_recycler.ThreadStats = {["Created"] = 0 ,["Count"] = 0, ["Recycled"] = 0} 
	local_recycler._open = {} 
	local_recycler._tcount = if Config["InitialThreadCount"] then Config["InitialThreadCount"] else SETTINGS.Default.threadCount
	local_recycler._time = if Config["CachedLifetime"] then Config["CachedLifetime"] else SETTINGS.Default.cachedtime
	local_recycler._enablestatrec = if Config["EnableStatRecording"] then Config["EnableStatRecording"] else SETTINGS.Default.enableStatRecording
	local_recycler._logger = if Config["Logger"] then Config["Logger"] else SETTINGS.Default.logger
	local_recycler._debug = if Config["Debug"] then Config["Debug"] else SETTINGS.Default.debug
end

function recycler._invoke<T...>(threads:recycler, thread:thread, callback: (thread:thread, T...) -> nil, ...: T...)
	local index = #threads._open
	local thread:thread = threads._open[index] 
	threads._open[index] = nil
	callback(thread, ...) 
	if threads._enablestatrec then threads.ThreadStats.Recycled += 1 end
	table.insert(threads._open, thread)
end

function recycler:_yield(closeThread: boolean)
	while not closeThread do
		self._invoke(self, coroutine.yield())
	end
end

function recycler._create(threads:recycler)
	local newThread: thread?
	newThread = coroutine.create(threads._yield) :: thread
	if threads._time ~= false then
		if #threads._open > threads._tcount then
			local index = #threads._open + 1
			task.delay(threads._time::number, function()
				newThread = nil
				threads._open[index] = nil
			end)
		end
	end
	coroutine.resume(newThread :: thread, threads :: recycler) --  recycler :: recycler
	if threads._enablestatrec then threads.ThreadStats.Created += 1 end
	table.insert(threads._open, newThread::thread)
end

--// ----- Public ----- //--

function recycler.getstat(threads:recycler, index: string)
	if type(threads) == "boolean" then threads = GlobalPool end -- backwards compatibility
	if threads._enablestatrec then
		threads.ThreadStats.Count = #threads._open
		local stat = threads.ThreadStats[index]
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

function recycler.recycle(threads:recycler, thread: thread)
	if threads._enablestatrec then threads.ThreadStats.Recycled += 1 end
	table.insert(threads._open, thread)
end

function recycler.wait(seconds: number | nil)
	local startTime = os.clock()
	while os.clock() - startTime < (if seconds then seconds else RunService.Heartbeat:Wait()) do
		RunService.Heartbeat:Wait()
	end
end


function recycler.construct(Config:{}) : recycler 
	local local_recycler: recycler = (setmetatable({}, recycler):: any)  :: recycler
	SetUpRecycler(local_recycler, Config)
	for n = 1, math.abs(local_recycler._tcount), 1 do
		local_recycler._create(local_recycler :: recycler)
	end
	return local_recycler :: recycler
end

function recycler.autocompatible<T...>(threads:recycler, callback: (T...) -> nil, ...: T...)
	local newThread: thread?
	local function invoke<T...>(thread, callback: (thread:thread, T...) -> nil, ...: T...)
		print("ThreadRecycler: Checking auto-recycling compatibility...") 
		print("ThreadRecycler: If 'This function supports auto-recyling!' doesn't show up at all, then threads must be manually recycled.")
		callback(thread::thread, ...) 
		warn("ThreadRecycler: This function supports auto-recycling!")
	end
	newThread = coroutine.create(function(closeThread:boolean)
		while not closeThread do
			invoke(coroutine.yield())
		end
	end) :: thread
	coroutine.resume(newThread :: thread) 
	return coroutine.resume(newThread::thread, newThread::thread, callback:: (T...) -> nil, ...)
end

function recycler.wrap<T...>(threads:recycler? | boolean, callback: (T...) -> nil, ...: T...)
	local specifiedThreads:recycler = if threads == nil or (threads == true or threads == false) then GlobalPool :: recycler else threads :: recycler -- bkds compatibility
	if #specifiedThreads._open < 1 then specifiedThreads._create(specifiedThreads) end
	local thread:thread = specifiedThreads._open[#specifiedThreads._open] :: thread
	return coroutine.resume(thread::thread, thread, callback:: (T...) -> nil, ...)
end

function recycler.spawn<T...>(threads:recycler? | boolean, callback: (T...) -> nil, ...: T...)
	local specifiedThreads:recycler = if threads == nil or (threads == true or threads == false) then GlobalPool :: recycler else threads :: recycler -- bkds compatibility
	if #specifiedThreads._open < 1 then specifiedThreads._create(specifiedThreads) end
	local thread:thread = specifiedThreads._open[#specifiedThreads._open] :: thread
	return task.spawn(thread::thread, thread,  callback:: (T...) -> nil, ...)
end


function recycler.defer<T...>(threads:recycler? | boolean, callback: (T...) -> nil, ...: T...)
	local specifiedThreads:recycler = if threads == nil or (threads == true or threads == false) then GlobalPool :: recycler else threads :: recycler -- bkds compatibility
	if #specifiedThreads._open < 1 then specifiedThreads._create(specifiedThreads) end
	local thread:thread = specifiedThreads._open[#specifiedThreads._open] :: thread
	recycler.wait()
	return coroutine.resume(thread::thread, thread, callback:: (T...) -> nil, ...)
end

function recycler.gooddefer<T...>(threads:recycler? | boolean, callback: (T...) -> nil, ...: T...)
	local specifiedThreads:recycler = if threads == nil or (threads == true or threads == false) then GlobalPool :: recycler else threads :: recycler -- bkds compatibility
	if #specifiedThreads._open < 1 then specifiedThreads._create(specifiedThreads) end
	local thread:thread = specifiedThreads._open[#specifiedThreads._open] :: thread
	RunService.Heartbeat:Wait()
	return coroutine.resume(thread::thread, thread, callback:: (T...) -> nil, ...)
end

function recycler.unsafedefer<T...>(threads:recycler? | boolean?, callback: (T...) -> nil, ...: T...) -- do not use
	local specifiedThreads:recycler = if threads == nil or (threads == true or threads == false) then GlobalPool :: recycler else threads :: recycler -- bkds compatibility
	if #specifiedThreads._open < 1 then specifiedThreads._create(specifiedThreads) end
	local thread:thread = specifiedThreads._open[#specifiedThreads._open]  :: thread
	return task.defer(thread::thread, thread,  callback:: (T...) -> nil, ...)
end

function recycler.delay<T...>(threads:recycler? | boolean, time:number, callback: (T...) -> nil, ...: T...)
	local specifiedThreads:recycler = if threads == nil or (threads == true or threads == false) then GlobalPool :: recycler else threads :: recycler -- bkds compatibility
	if #specifiedThreads._open < 1 then specifiedThreads._create(specifiedThreads) end
	local thread:thread = specifiedThreads._open[#specifiedThreads._open] :: thread
	recycler.wait(time)
	return coroutine.resume(thread::thread, thread, callback:: (T...) -> nil, ...)
end

function recycler.unsafedelay<T...>(threads:recycler? | boolean, time:number, callback: (T...) -> nil, ...: T...) -- do not use
	local specifiedThreads:recycler = if threads == nil or (threads == true or threads == false) then GlobalPool :: recycler else threads :: recycler -- bkds compatibility
	if #specifiedThreads._open < 1 then specifiedThreads._create(specifiedThreads) end
	local thread:thread = specifiedThreads._open[#specifiedThreads._open] :: thread
	return task.delay(time, thread::thread, thread,  callback:: (T...) -> nil, ...)
end

GlobalPool = recycler.construct({
	["InitialThreadCount"] = SETTINGS.Default.threadCount; 
	["CachedLifetime"] = SETTINGS.Default.cachedtime; 
	["EnableStatRecording"] = SETTINGS.Default.enableStatRecording; 
	["Logger"] = SETTINGS.Default.logger; 
	["Debug"] = SETTINGS.Default.debug 
}) :: recycler

setmetatable(recycler, {
	__index = function(self, key)
		warn("ThreadRecycler: Failed to initiate.")
		error(string.format("ThreadRecycler: %q is not a valid key of ThreadRecycler.",
			tostring(key)), 2)
	end,
}) 


return (recycler :: any) :: recycler

-- Not used
--// ----- Prerequisite Modules ----- //--
--// ----- Initialize ----- //--
--// ----- Connections ----- //--
