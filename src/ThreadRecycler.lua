--!strict
--!native
-- Version 0.2.1-a.2
--@illinois_roadbuff

local t = {} -- t: Threads
t.__index = t

type t = {
	_c: boolean, -- _c: Callback? (Manual recycling?)
	_t: thread, -- _t: Thread
}

type r = { -- r: Recycling pool?
	_t: number, -- Thread count
	_o: {t}, -- _o: Open threads
	_i: number, -- _i = Next index
	_c: () -> nil, -- _c: Call
	_n: (boolean) -> t, -- _n: Create thread
	_y: () -> nil, -- _y: Yield
	spawn:<T...> (boolean, (T...) -> nil, T...) -> nil,
	defer:<T...> (boolean, (T...) -> nil, T...) -> nil,
	wrap:<T...> (boolean, (T...) -> nil, T...) -> nil,
	delay:<T...> (boolean, number,  (T...) -> nil, T...) -> nil
}

local r: r  = {} :: r
setmetatable(r::r, t::t)

r._t = 30 :: number --negative = dynamic
r._o = {} :: {t}

local StartOnSignal:boolean = true :: boolean
local i:number = 1 :: number
local threadMetatable = {
	__index = function(thread, key:string)
		if key == "signal" then	return thread._c end
		if key == "coroutine" then return thread._t end
		return rawget(thread, key)
	end
}

function t.recycle(index)
	local thread:t = r._o[index]
	r._o[i] = thread
	i += 1
end

function t._call<T...>(callback: (T...) -> nil, ...: T...)
	local thread:t = r._o[ - 1]
	if not thread then
		t._createThread(false)  
		thread = r._o[i - 1]
	end
	r._o[i - 1] = nil
	i -= 1
	if callback and typeof(callback) == "table" or typeof(callback) == "function" then
		if thread._c then callback(...) else callback(...)
			r._o[i] = thread
			i += 1
		end
	else warn(`ThreadRecycler: Invalid callback recived: {typeof(callback)}. Is your callback a function?`) end
end

function t:_y(closeThread: boolean)
	while not closeThread do
		t._call(coroutine.yield())
	end
	return
end

function t._createThread(UseSignal: boolean)
	local newThread: t | nil
	newThread = setmetatable({}, threadMetatable) :: t
	newThread._c = UseSignal :: boolean
	newThread._t = coroutine.create(r._y) :: thread
	coroutine.resume(newThread._t :: thread, r :: r)
	r._o[i] = newThread
	i += 1
end

function t.spawn<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #r._o < 1 then t._createThread(UseSignal) end
	local thread:t = r._o[i - 1]
	local index = i - 1::number
	thread._c = UseSignal
	local status:string = coroutine.status(thread._t)
	if  status == "suspended" then
		if not UseSignal then
			task.spawn(thread._t::thread, callback:: (T...) -> nil, ...)
		else
			task.spawn(thread._t::thread, callback:: (T...) -> nil, index::number, ...)
		end
	elseif  status == "dead" then
		task.cancel(thread._t)
		r._o[i - 1] = nil
		i -= 1
		t._createThread(UseSignal)
		t.spawn(UseSignal, callback, ...) 
	end
end

function t.wrap<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #r._o < 1 then t._createThread(UseSignal) end
	local thread:t = r._o[i - 1]
	local index = i - 1::number
	thread._c = UseSignal
	local status = coroutine.status(thread._t)
	if  status == "suspended" then
		if not UseSignal then
			coroutine.resume(thread._t, callback, ...)
		else
			coroutine.resume(thread._t, callback, index, ...) 
		end
	elseif  status == "dead" then
		r._o[i - 1] = nil
		i -= 1
		t._createThread(UseSignal)
		t.wrap(UseSignal, callback, ...) 
	end
end

function t.defer<T...>(UseSignal:boolean, callback: (T...) -> nil, ...: T...)
	if #r._o < 1 then t._createThread(UseSignal) end
	local thread:t = r._o[i - 1]
	local index = i - 1::number
	thread._c = UseSignal
	local status = coroutine.status(thread._t)
	if  status == "suspended" then
		if not UseSignal then
			task.wait()
			coroutine.resume(thread._t, callback, ...)
		else
			task.wait()
			coroutine.resume(thread._t, callback, index, ...)
		end
	elseif  status == "dead" then
		r._o[i - 1] = nil
		i -= 1
		t._createThread(UseSignal)
		t.defer(UseSignal, callback, ...)
	end
end

function t.delay<T...>(UseSignal, time:number, callback: (T...) -> nil, ...: T...)
	if #r._o < 1 then t._createThread(UseSignal) end
	local thread:t = r._o[i - 1]
	local index = i - 1::number
	thread._c = UseSignal
	local status = coroutine.status(thread._t)
	if  status == "suspended" then
		if not UseSignal then
			task.wait(time)
			coroutine.resume(thread._t, callback, ...)
		else
			task.wait(time)
			coroutine.resume(thread._t, callback, ...)
		end
	elseif  status == "dead" then
		r._o[i - 1] = nil
		i -= 1
		t._createThread(UseSignal)
		t.delay(UseSignal, t, callback, ...)
	end
end

for n = 1, math.abs(r._t), 1 do
	t._createThread(StartOnSignal)
end
return t
