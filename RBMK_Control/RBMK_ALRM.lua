
local e = require("event")
local component = require("component")
local gpulib = require("gpulib")
local sides = require("sides")

--- Default table for tanks.
local tank = {
	amount = 0,
	max = 0,
	fluid = "",
	index = 0,
	proxy = {}
}

running  = true
updateProg  = false
tanks = {}
updateRBMK  = false
pErrors = {}
RBMKAlarms = {}

--- Create a new tank using the LUA OOP.
function tank:new(proxy, amount,max, fluid)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	self.amount = amount
	self.max = max
	self.fluid = fluid
	self.index = #tanks + 1
	self.proxy = proxy
	return o
end

--- Update the tank's values based on the component data.
function tank:update()
	self.amount = self.proxy.getFluidStored
end

function tank:type()
	return self.fluid
end

function tank:max()
	return self.max
end

function tank:fluid()
	return self.amount
end

for x, y in component.list("ntm_") do
	if not(y == "ntm_geiger") then
		local object = component.proxy(x)
		local a = tank:new(object, object.getFluidStored, object.getMaxStored, object.getFluidStored)
		table.insert(tanks, a)
	end
end

local geiger = component.proxy("fe8e80dc-8c66-4f6b-a02e-48426e1c2b3a")
local RAD_SEN_TURBINE= component.proxy("a59e72c9-cbfd-46c3-b244-202b4df7f454")
local RAD_SEN_CONTROL= component.proxy("1a73157f-82b3-4a8e-8829-1af920b714a1")

local function addPError(label, fatal)
	fatal = fatal or false
	if fatal then
		print("Fatal error has occurred, terminating...")
		print(debug.traceback())
		os.exit()
		return nil
	end
	table.insert(pErrors, label)
	updateProg = true
	return nil
end

local function addRBMKAlarm(label)
	table.insert(RBMKAlarms, label)
	UpdateRBMK = true
	return nil
end


local function hasValue(table, value)
	for _, y in pairs(table) do
		if y == value then
			return true
		end
	end
	return false
end

local function run()
	running = false
end

e.listen("interrupted", run)
local memory = gpulib.VRAM_state()
if memory[1] < 13000 then
	running = false
	print("GPU Memory insufficient for running this program, change to a T3 graphics card.")
	os.exit()
else
	print("GPU Memory sufficient, continuing.")
end
if not(gpulib.getBuffers() == {}) then
	gpulib.clear() -- clear all buffers if buffers already exist (required for the program to function correctly)
end
-- main loop
-- screen is index 0
gpulib.createBuffer(160, 50) -- screen buffer (index 1)
gpulib.createBuffer(100, 50) -- other icons (index 2)
local p_counter = 0
while running do
	p_counter = p_counter + 1
	for x in pairs(tanks) do
		tanks[x]:update()
	end
	local status = gpulib.VRAM_state()
	if status[1] < 2000 then
		if not hasValue(pErrors, "LOW GPU VRAM") then
			addPError("LOW GPU VRAM", false)
		end
	end
	if RAD_SEN_CONTROL.getInput(sides.top) > 0 then
		if not hasValue(RBMKAlarms, "RADIATION DETECTED IN CONTROL ROOM") then
			addRBMKAlarm("RADIATION DETECTED IN CONTROL ROOM")
		end
	end
		if RAD_SEN_TURBINE.getInput(sides.top) > 0 then
			if not hasValue(RBMKAlarms, "RADIATION DETECTED IN TURBINE AREA") then
				addRBMKAlarm("RADIATION DETECTED IN TURBINE AREA")
			end
	end
	if running then
		if not hasValue(pErrors, "PROGRAM RUNNING") then
			addPError("PROGRAM RUNNING")
		end
	end
	if geiger.getRads() > 5 then
		if not hasValue(RBMKAlarms, "HIGH RADIATION DETECTED IN REACTOR AREA") then
			addRBMKAlarm("HIGH RADIATION DETECTED IN REACTOR AREA")
		end
	end
	gpulib.writeArea({120, 0, 50, 50, " "}, 1)
	gpulib.writeData({102, 1, os.date() .. " Frame count:" .. p_counter}, 1)
	if updateProg and p_counter % 20 < 10 then 	-- program errors handling
		for x, y in pairs(pErrors) do
			gpulib.writeData({102, 2 + x, y}, 1)
		end
	end
	if updateRBMK and p_counter % 20 < 10 then 	-- RBMK alarm handling
		for x, y in pairs(RBMKAlrms) do
			gpulib.writeData({102, 22 + x, y}, 1)
		end
	end

	gpulib.bitblt(0, 1, 160, 50, 0, 0, 0, 0) -- move screen buffer to screen when ready
	os.sleep(0.01)
end
while #RBMKAlarms > 0 do
	table.remove(RBMKAlarms)
end
while #pErrors > 0 do
	table.remove(pErrors)
end
e.ignore("interrupted", run)
gpulib.clear()