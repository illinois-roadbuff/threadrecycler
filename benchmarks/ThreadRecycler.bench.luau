--[[
This file is for use by Benchmarker (https://boatbomber.itch.io/benchmarker)

|WARNING| THIS RUNS IN YOUR REAL ENVIRONMENT. |WARNING|
--]]


local ThreadRecycler = require(game.ReplicatedStorage.ThreadRecycler)


local NewThread = ThreadRecycler.erect({
	["InitialThreadCount"] = 10,
	["CachedLifetime"] = 60,
	["EnableStatRecording"] = true,
	["Logger"] = warn,
	["Debug"] = false 
})


--[[task.spawn(function()
task.wait(20)
local success, recycledValue = NewThread.getstat(NewThread, "Recycled")
local success, createdValue = NewThread.getstat(NewThread, "Created")
local success, countValue = NewThread.getstat(NewThread, "Count")
	warn(`Stats: Recycled: {recycledValue} | Created: {createdValue} | Count: {countValue} `)
end)]]

return {
	ParameterGenerator = function()
		return 
	end,

	Functions = {
		
	--[[	["coroutine.wrap"] = function(Profiler, RandomNumber)
			for i = 1, 10000 do
				 coroutine.resume(coroutine.create(function()
				
				end))
			end
		end,

		["recycled.wrap"] = function(Profiler, RandomNumber)
			for i = 1, 10000 do

				NewThread.wrap(NewThread, function(i)
			
			
				end)
			end

	end,]]
	

		["task.spawn"] = function(Profiler, RandomNumber)
			for i = 1, 10000 do
				task.spawn(function()
				
				end)
			end
		end,

		["recycled.spawn"] = function(Profiler, RandomNumber)
			for i = 1, 10000 do

				NewThread.spawn(NewThread, function(i)
				

				end)
			end

		end,

	},

}


