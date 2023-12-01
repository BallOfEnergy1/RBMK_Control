
-- CONFIG


--                                      VERSION 1 - RBMK_MONITOR


--- Whether or not the program will automatically be updated from pastebin.
local auto_update = true

--- Program-specific config. Cannot be editied for the time being without auto-update screwing it up
local CONFIG = {
	maxheat = 1500,
	bmaxheat = 600,
	maxautoheat = 1500,
	s1autoheat = 200,
	s2autoheat = 400,
	s3autoheat = 800,
	s4autoheat = 1000,
	basestep = 5,
	auto1basestep = 5,
	auto2basestep = 1
}

-- Loading libraries and error/network handlers.
local function Fatal_err(err)
	print(debug.traceback("FATAL ERROR: " .. err))
	return nil
end
local component = require("component")
local e = require("event")
---Pushes an error to console with the text `err`
---@param err string
---@return nil
local function Warn_err(err)
	require("component").gpu.setForeground(0xFFFF00)
	print("WARN: " .. err)
	require("component").gpu.setForeground(0xFFFFFF)
	return nil
end

local funclib = require("funclib")
local gpulib = require("gpulib")
local gpucomp = component.gpu
local invoke = component.invoke
local rs -- Library initialization (until defined later)

-- Check for updates on github (EXPERIMENTAL)
if component.isAvailable("internet") then
	-- Check for updates
	os.execute("wget \"https://raw.githubusercontent.com/BallOfEnergy1/RBMK_Control/master/RBMK_Control/RBMK_Monitor.lua\" \"/RBMK_Control/recent_ver.lua\" -f")
	local updated_file = io.open("/RBMK_Control/recent_ver.lua")
	if updated_file:read("*a") == "" then
		Warn_err("Failed to check for updates, contact support for assistance.")
		updated_file:close()
		os.remove("/RBMK_Control/recent_ver.lua")
	else
		local existing_file = io.open("/RBMK_Control/RBMK_Monitor.lua")
		if updated_file:read("*a") == existing_file:read("*a") then
			print("Program is up-to-date.")
			os.remove("/RBMK_Control/recent_ver.lua")
		elseif auto_update then
			print("Updating program...")
			require("filesystem").copy("/recent_ver.lua", "/RBMK_Control/RBMK_Monitor.lua")
			print("Update Successful!")
			os.remove("/RBMK_Control/recent_ver.lua")
		else
			print("Program is out of date; Auto-update is disabled.")
		end
		updated_file:close()
		existing_file:close()
	end
else
	print("Internet card is required for updating; Restart the program with an internet card to update, or continue with startup.")
end

-- Variable assignment.

-- Tables for rods/control.
-- Fuel Tables
local rbmkfuel = "rbmk_fuel_rod"
local rbmkfuel_table = {}

local rbmkfuel_heat = {}
local rbmkfuel_Hheat = {}
local rbmkfuel_Cheat = {}
local rbmkfuel_Fflux = {}
local rbmkfuel_Sflux = {}
local rbmkfuel_Depletion = {}
local rbmkfuel_Xenon = {}

-- Boiler Tables
local rbmkboiler = "rbmk_boiler"
local rbmkboiler_table = {}

local rbmkboiler_heat = {}
local rbmkboiler_water = {}
local rbmkboiler_maxW = {}
local rbmkboiler_steam = {}
local rbmkboiler_maxS = {}
local rbmkboiler_type = {}

-- Control Tables
local rbmkctrl = "rbmk_control_rod"
local rbmkctrl_table = {}

local ctrl_levels = {}
local ctrl_colors = {}
local rbmkctrlheat_table = {}

-- Heater Tables
local rbmkheater = "rbmk_heater"
local rbmkheater_table = {}

-- Outgasser Tables
local rbmkoutgasser = "rbmk_outgasser"
local rbmkoutgasser_table = {}

-- Cooler Tables
local rbmkcooler = "rbmk_cooler"
local rbmkcooler_table = {}

-- Energy Tables
local energy = "ntm_energy_storage"
local energy_table = {}

-- Miscellaneous
local desync = {}
local pad = "            "
local running = true
local overview_page = true

-- Control variables.
local Coolers, Outgassers, Boilers, Heaters, redstone_enabled, AUTO

-- Page variables.
local boiler_page, control_page, fuel_page, heater_page, cooler_page, outgasser_page


-- Define functions needed by the program.
--- Function for detecting if a user has clicked a button or area.
--- @param x number
--- @param y number
local function touch(x, y)
	if x >= 19 and x <= 29 and y >= 1 and y <= 3 then
		overview_page = true
		boiler_page, control_page, fuel_page, heater_page, cooler_page, outgasser_page = false
	elseif x >= 30 and x <= 41 and y >= 1 and y <= 3 then
		fuel_page = true
		boiler_page, control_page, overview_page, heater_page, cooler_page, outgasser_page = false
	elseif x >= 42 and x <= 56 and y >= 1 and y <= 3 then
		control_page = true
		boiler_page, fuel_page, overview_page, heater_page, cooler_page, outgasser_page = false
	elseif x >= 57 and x <= 66 and y >= 1 and y <= 3 then
		boiler_page = true
		fuel_page, control_page, overview_page, heater_page, cooler_page, outgasser_page = false
	elseif x >= 67 and x <= 76 and y >= 1 and y <= 3 then
		cooler_page = true
		boiler_page, control_page, overview_page, heater_page, fuel_page, outgasser_page = false
	elseif x >= 77 and x <= 91 and y >= 1 and y <= 3 then
		outgasser_page = true
		boiler_page, control_page, fuel_page, heater_page, cooler_page, overview_page = false
	elseif x >= 92 and x <= 107 and y >= 1 and y <= 3 then
		heater_page = true
		boiler_page, control_page, overview_page, fuel_page, cooler_page, outgasser_page = false
	else

	end
end

local function getAverageRodData(rodType)
	if rodType == "fuel" then
		local value_1_avg, value_2_avg, value_3_avg, value_4_avg, value_5_avg, value_6_avg, value_7_avg, value_8_avg
		local value_1_2, value_2_2, value_3_2, value_4_2, value_5_2, value_6_2, value_7_2 = 0, 0, 0, 0, 0, 0, 0
		for _, address in pairs(rbmkfuel_table) do
			local value_1, value_2, value_3, value_4, value_5, value_6, value_7, value_8 = invoke(address, "getInfo")
			if not(type(value_2) == "string") then
				value_2_2 = value_2_2 + value_2 -- number
				value_3_2 = value_3_2 + value_3 -- number
				value_6_2 = value_6_2 + value_6 -- number
				value_7_2 = value_7_2 + value_7 -- number
			end
			value_1_2 = value_1_2 + value_1 -- number
			value_4_2 = value_4_2 + value_4 -- number
			value_5_2 = value_5_2 + value_5 -- number
			value_8_avg = value_8 -- boolean
		end
		value_1_avg = value_1_2 / #rbmkfuel_table
		value_4_avg = value_4_2 / #rbmkfuel_table
		value_5_avg = value_5_2 / #rbmkfuel_table
		if type(value_2_avg) == "string" then
			value_2_avg = "N/A"
			value_3_avg = "N/A"
			value_6_avg = "N/A"
			value_7_avg = "N/A"
		else
			value_2_avg = value_2_2 / #rbmkfuel_table
			value_3_avg = value_3_2 / #rbmkfuel_table
			value_6_avg = value_6_2 / #rbmkfuel_table
			value_7_avg = value_7_2 / #rbmkfuel_table
		end
		return value_1_avg, value_2_avg, value_3_avg, value_4_avg, value_5_avg, value_6_avg, value_7_avg, value_8_avg
	end
	if rodType == "ctrl" then
		local value_1_avg, value_2_avg, value_3_avg
		local value_1_2, value_2_2, value_3_2 = 0, 0, 0
		for _, address in pairs(rbmkctrl_table) do
			local value_1, value_2, value_3 = invoke(address, "getInfo")
			value_1_2 = value_1_2 + value_1 -- number
			value_2_2 = value_2_2 + value_2 -- number
			value_3_2 = value_3_2 + value_3 -- number
		end
		value_1_avg = value_1_2 / #rbmkctrl_table
		value_2_avg = value_2_2 / #rbmkctrl_table
		value_3_avg = value_3_2 / #rbmkctrl_table
		return value_1_avg, value_2_avg, value_3_avg
	end
	if rodType == "boiler" then
		local value_1_avg, value_2_avg, value_3_avg, value_4_avg, value_5_avg
		local value_1_2, value_2_2, value_3_2, value_4_2 = 0, 0, 0, 0
		for _, address in pairs(rbmkboiler_table) do
			local value_1, value_2, value_3, value_4, value_5 = invoke(address, "getInfo")
			value_1_2 = value_1_2 + value_1 -- number
			value_2_2 = value_2_2 + value_2 -- number
			value_3_2 = value_3_2 + value_3 -- number
			value_4_2 = value_4_2 + value_4 -- number
			value_5_avg = value_5 -- fluid ID (string)
		end
		value_1_avg = value_1_2 / #rbmkboiler_table
		value_2_avg = value_2_2 / #rbmkboiler_table
		value_3_avg = value_3_2 / #rbmkboiler_table
		value_4_avg = value_4_2 / #rbmkboiler_table
		return value_1_avg, value_2_avg, value_3_avg, value_4_avg, value_5_avg
	end
	if rodType == "heater" then
		local value_1_avg, value_2_avg, value_3_avg, value_4_avg, value_5_avg, value_6_avg, value_7_avg
		local value_1_2, value_2_2, value_3_2, value_4_2, value_5_2 = 0, 0, 0, 0, 0
		for _, address in pairs(rbmkheater_table) do
			local value_1, value_2, value_3, value_4, value_5, value_6, value_7 = invoke(address, "getInfo")
			value_1_2 = value_1_2 + value_1 -- number
			value_2_2 = value_2_2 + value_2 -- number
			value_3_2 = value_3_2 + value_3 -- number
			value_4_2 = value_4_2 + value_4 -- number
			value_5_2 = value_5_2 + value_5 -- number
			value_6_avg = value_6 -- fluid ID (string)
			value_7_avg = value_7 -- fluid ID (string)
		end
		value_1_avg = value_1_2 / #rbmkheater_table
		value_2_avg = value_2_2 / #rbmkheater_table
		value_3_avg = value_3_2 / #rbmkheater_table
		value_4_avg = value_4_2 / #rbmkheater_table
		value_5_avg = value_5_2 / #rbmkheater_table
		return value_1_avg, value_2_avg, value_3_avg, value_4_avg, value_5_avg, value_6_avg, value_7_avg
	end
	if rodType == "outgasser" then
		local value_1_avg, value_2_avg, value_3_avg, value_4_avg
		local value_1_2, value_2_2, value_3_2 = 0, 0, 0
		for _, address in pairs(rbmkoutgasser_table) do
			local value_1, value_2, value_3, value_4 = invoke(address, "getInfo")
			value_1_2 = value_1_2 + value_1 -- number
			value_2_2 = value_2_2 + value_2 -- number
			value_3_2 = value_3_2 + value_3 -- number
			value_4_avg = value_4 -- fluid ID (string)
		end
		value_1_avg = value_1_2 / #rbmkoutgasser_table
		value_2_avg = value_2_2 / #rbmkoutgasser_table
		value_3_avg = value_3_2 / #rbmkoutgasser_table
		return value_1_avg, value_2_avg, value_3_avg, value_4_avg
	end
	if rodType == "cooler" then
		local value_1_avg, value_2_avg, value_3_avg
		local value_1_2, value_2_2, value_3_2 = 0, 0, 0
		for _, address in pairs(rbmkcooler_table) do
			local value_1, value_2, value_3 = invoke(address, "getInfo")
			value_1_2 = value_1_2 + value_1 -- number
			value_2_2 = value_2_2 + value_2 -- number
			value_3_2 = value_3_2 + value_3 -- number
		end
		value_1_avg = value_1_2 / #rbmkcooler_table
		value_2_avg = value_2_2 / #rbmkcooler_table
		value_3_avg = value_3_2 / #rbmkcooler_table
		return value_1_avg, value_2_avg, value_3_avg
	end
end

local function getRodData(rodType, rodIndex)
	if rodType == "fuel" then
		local value_1, value_2, value_3, value_4, value_5, value_6, value_7, value_8 = invoke(rodIndex, "getInfo")
		return value_1, value_2, value_3, value_4, value_5, value_6, value_7, value_8
	end
	if rodType == "ctrl" then
		local value_1, value_2, value_3 = invoke(rodIndex, "getInfo")
		return value_1, value_2, value_3
	end
	if rodType == "boiler" then
		local value_1, value_2, value_3, value_4, value_5 = invoke(rodIndex, "getInfo")
		return value_1, value_2, value_3, value_4, value_5
	end
	if rodType == "heater" then
		local value_1, value_2, value_3, value_4, value_5, value_6, value_7 = invoke(rodIndex, "getInfo")
		return value_1, value_2, value_3, value_4, value_5, value_6, value_7
	end
	if rodType == "outgasser" then
		local value_1, value_2, value_3, value_4 = invoke(rodIndex, "getInfo")
		return value_1, value_2, value_3, value_4
	end
	if rodType == "cooler" then
		local value_1, value_2, value_3 = invoke(rodIndex, "getInfo")
		return value_1, value_2, value_3
	end
end

-- User Confirmation.
do
	local user = ""
	print("Enable redstone output? Y/N")
	user = io.read()
	if user == "y" or user == "Y" then
		redstone_enabled = true
		rs = component.redstone
	elseif user == "n" or user == "N" then
		redstone_enabled = false
		rs = ""
	else
		Warn_err("INVALID_CHAR")
		os.exit()
	end
	print("Are there boiler columns present in the reactor? Y/N")
	user = io.read()
	if user == "y" or user == "Y" then
		Boilers = true
	elseif user == "n" or user == "N" then
		Boilers = false
	else
		Warn_err("INVALID_CHAR")
		os.exit()
	end
	print("Are there cooler columns present in the reactor? Y/N")
	user = io.read()
	if user == "y" or user == "Y" then
		Coolers = true
	elseif user == "n" or user == "N" then
		Coolers = false
	else
		Warn_err("INVALID_CHAR")
		os.exit()
	end
	print("Are there irradiation columns present in the reactor? Y/N")
	user = io.read()
	if user == "y" or user == "Y" then
		Outgassers = true
	elseif user == "n" or user == "N" then
		Outgassers = false
	else
		Warn_err("INVALID_CHAR")
		os.exit()
	end
	print("Are there heating columns present in the reactor? Y/N")
	user = io.read()
	if user == "y" or user == "Y" then
		Heaters = true
	elseif user == "n" or user == "N" then
		Heaters = false
	else
		Warn_err("INVALID_CHAR")
		os.exit()
	end
	for address, _ in component.list(rbmkctrl) do
		table.insert(rbmkctrl_table, address)
	end
	for address, _ in component.list(rbmkfuel) do
		table.insert(rbmkfuel_table, address)
	end
	for address, _ in component.list(energy) do
		table.insert(energy_table, address)
	end
	if Coolers then
		for address, _ in component.list(rbmkcooler) do
			table.insert(rbmkcooler_table, address)
		end
	end
	if Outgassers then
		for address, _ in component.list(rbmkoutgasser) do
			table.insert(rbmkoutgasser_table, address)
		end
	end
	if Boilers then
		for address, _ in component.list(rbmkboiler) do
			table.insert(rbmkboiler_table, address)
		end
	end
	if Heaters then
		for address, _ in component.list(rbmkheater) do
			table.insert(rbmkheater_table, address)
		end
	end
	print("FOUND COMPONENTS:")
	print("Type", "", "Address")
	for _, value in pairs(rbmkctrl_table) do
		print("CTRL_", " ---- ", value)
	end
	for _, value in pairs(rbmkfuel_table) do
		print("FUEL_",  " ---- ", value)
	end
	for _, value in pairs(energy_table) do
		print("STOR_",  " ---- ", value)
	end
	if Boilers then
		for _, value in pairs(rbmkboiler_table) do
			print("BOIL_", "----", value)
		end
	end
	if Outgassers then
		for _, value in pairs(rbmkoutgasser_table) do
			print("OUTG_", "----", value)
		end
	end
	if Coolers then
		for _, value in pairs(rbmkcooler_table) do
			print("COOL_", "----", value)
		end
	end
	if Heaters then
		for _, value in pairs(rbmkheater_table) do
			print("HEAT_", "----", value)
		end
	end
	print("Are all components listed? Y/N")
	local op1 = io.read()
	if op1 == "N" then
		print("Terminating...")
		os.exit(0x01)
	elseif not(op1 == "Y" or op1 == "y") then
		Warn_err("INVALID_CHAR")
		os.exit()
	end
end

-- User input for starting level.
do
	local config_startup_level
	print("Input starting control rod level.")
	local read = io.read()
	if tonumber(read) == nil then
		print("Invalid Value.")
		Warn_err("INVALID_VALUE")
		os.exit()
	else
		config_startup_level = tonumber(read)
	end
	if config_startup_level < 50 and config_startup_level >= 0 then
		print("Starting level is below 50 (" .. config_startup_level .. "). Continue? Y/N")
		local a = io.read()
		if a == "N" or a == "n" then
			os.exit(0x01)
		elseif not(a == "Y" or a == "y") then
			print("Invalid Char.")
			Warn_err("INVALID_CHAR")
			os.exit()
		end
	elseif config_startup_level >= 50 and config_startup_level < 100 then
		print("Starting level is " ..  config_startup_level .. ", Confirm?")
		local a = io.read()
		if a == "N" or a == "n" then
			os.exit(0x01)
		elseif not(a == "Y" or a == "y") then
			print("Invalid Char.")
			Warn_err("INVALID_CHAR")
			os.exit()
		end
	elseif config_startup_level > 100 or config_startup_level < 0 then
		print("Invalid starting level. ( " .. config_startup_level .. " )")
		Warn_err("INVALID_NUM")
		os.exit()
	end
	for _, a in pairs(rbmkctrl_table) do
		invoke(a, "setLevel", config_startup_level)
		table.insert(ctrl_levels, config_startup_level)
	end
	print("Initiating startup...")
end
local function touch1(_, _, x, y)
	xpcall(touch, Warn_err, x, y)
end
local function run()
	running = false
end
for _ in pairs(rbmkctrl_table) do
	table.insert(desync, false)
end
-- 1 is basic UI
-- 2 is miscellaneous
-- Initialize GPU VRAM buffers along with filling them with content.
local function draw_basics()
	gpulib.createBuffer(160, 50) -- ID should be 1.
	gpulib.createBuffer(60, 60) -- ID should be 2.
	gpucomp.setBackground(0x002400)
	gpulib.writeArea({1, 1, 160, 50, " "}, 1)
	gpucomp.setForeground(0xffffff)
	gpucomp.setBackground(0x969696)
	gpucomp.fill(1, 1, 150, 3, " ")
	gpucomp.set(2, 2, os.date())
	gpucomp.setBackground(0x2D2D2D)
	gpucomp.fill(19, 1, 29, 3, " ")
	gpucomp.set(20, 2, "Overview")
	gpucomp.setBackground(0x3C3C3C)
	gpucomp.fill(30, 1, 41, 3, " ")
	gpucomp.set(31, 2, "Fuel rods")
	gpucomp.setBackground(0x4B4B4B)
	gpucomp.fill(42, 1, 56, 3, " ")
	gpucomp.set(43, 2, "Control rods")
	gpucomp.setBackground(0x5A5A5A)
	gpucomp.fill(57, 1, 66, 3, " ")
	gpucomp.set(58, 2, "Boilers")
	gpucomp.setBackground(0x696969)
	gpucomp.fill(67, 1, 76, 3, " ")
	gpucomp.set(68, 2, "Coolers")
	gpucomp.setBackground(0x787878)
	gpucomp.fill(77, 1, 91, 3, " ")
	gpucomp.set(78, 2, "Irradiatiors")
	gpucomp.setBackground(0x878787)
	gpucomp.fill(92, 1, 107, 3, " ")
	gpucomp.set(93, 2, "Fluid heaters")
end
e.listen("touch", touch1)
e.listen("interrupted", run)
-- Primary loop
while running do
	while #rbmkctrlheat_table > 0 do
		table.remove(rbmkctrlheat_table)
	end
	if overview_page then
		while #ctrl_colors > 0 do
			table.remove(ctrl_colors)
		end
		for _, a in pairs(rbmkctrl_table) do
			local b = invoke(a, "getColor")
			if not(b == nil) then
				table.insert(ctrl_colors, b)
			else
				table.insert(ctrl_colors, "NONE")
			end
		end
		for i, v in pairs(rbmkctrl_table) do
			local a, b = invoke(v, "getInfo")
			table.insert(rbmkctrlheat_table, a)
			if not(b == ctrl_levels[i]) then
				invoke(v, "setLevel", ctrl_levels[i])
				desync[i] = true
			else
				desync[i] = false
			end
		end
		local average_heat, average_slow_flux, average_fast_flux, average_depletion, average_xenon_poison = getAverageRodData("fuel")
		if Boilers then
			local average_boiler_heat, average_boiler_steam, average_boiler_steam_capacity, average_boiler_water, average_boiler_water_capacity, boiler_type = getAverageRodData("fuel")
		end
		draw_basics()
		gpucomp.setBackground(0x004900)
		gpucomp.fill(7, 7, 146, 40, " ")
		gpucomp.set(8, 8, "RBMK Overview")
		gpucomp.set(9, 10, "Average Heat: " .. string.sub(tostring(average_heat), 1, 6) .. "°C" .. pad)
		gpucomp.set(9, 12, "Slow Flux: " .. string.sub(tostring(average_slow_flux), 1, 6) .. "cm²/s" .. pad)
		gpucomp.set(9, 13, "Fast Flux: " .. string.sub(tostring(average_fast_flux), 1, 6) .. "cm²/s" .. pad)
		gpucomp.set(9, 15, "Enrichment: " .. string.sub(tostring(average_depletion), 1, 6) .. "%" .. pad)
		gpucomp.set(9, 16, "Xenon Poisoning: " .. string.sub(tostring(average_xenon_poison), 1, 6) .. "%" .. pad)
	end
	if fuel_page then
		while #rbmkfuel_heat > 0 do
			table.remove(rbmkfuel_heat)
			table.remove(rbmkfuel_Fflux)
			table.remove(rbmkfuel_Sflux)
			table.remove(rbmkfuel_Depletion)
			table.remove(rbmkfuel_Xenon)
		end
		--for i, v in pairs(rbmkctrl_table) do
		--	local a, b = invoke(v, "getInfo")
		--	table.insert(rbmkctrlheat_table, a)
		--	if not(b == ctrl_levels[i]) then
		--		invoke(v, "setLevel", ctrl_levels[i])
		--		desync[i] = true
		--	else
		--		desync[i] = false
		--	end
		--end
		local heat_1, hull_1, core_1, Sflux_1, Fflux_1, depletion_1, xenon_poison_1 = 0, 0, 0, 0, 0, 0, 0
		for _, v in pairs(rbmkfuel_table) do
			local heat, hull, core, Sflux, Fflux, depletion, xenon_poison = getRodData("fuel", v)
			table.insert(rbmkfuel_heat, heat)
			table.insert(rbmkfuel_Hheat, hull)
			table.insert(rbmkfuel_Cheat, core)
			table.insert(rbmkfuel_Sflux, Sflux)
			table.insert(rbmkfuel_Fflux, Fflux)
			table.insert(rbmkfuel_Depletion, depletion)
			table.insert(rbmkfuel_Xenon, xenon_poison)
			heat_1 = heat + heat_1
			Sflux_1 = Sflux + Sflux_1
			Fflux_1 = Fflux + Fflux_1
			if type(depletion) == "string" then
				hull_1 = hull
				core_1 = core
				depletion_1 = depletion
				xenon_poison_1 = xenon_poison
			else
				hull_1 = hull + hull_1
				core_1 = core + core_1
				depletion_1 = depletion + depletion_1
				xenon_poison_1 = xenon_poison + xenon_poison_1
			end
		end
		local average_heat = heat_1 / #rbmkfuel_table
		local average_slow_flux = Sflux_1 / #rbmkfuel_table
		local average_fast_flux = Fflux_1 / #rbmkfuel_table
		local average_depletion
		local average_xenon_poison
		local average_hull_heat
		local average_core_heat
		if type(depletion_1) == "string" then
			average_depletion = "N/A"
			average_xenon_poison = "N/A"
			average_hull_heat = "N/A"
			average_core_heat = "N/A"
		else
			average_depletion = depletion_1 / #rbmkfuel_table
			average_xenon_poison = xenon_poison_1 / #rbmkfuel_table
			average_hull_heat = hull_1 / #rbmkfuel_table
			average_core_heat= core_1 / #rbmkfuel_table

		end
		draw_basics()
		gpucomp.setBackground(0x004900)
		gpucomp.fill(7, 7, 146, 40, " ")
		gpucomp.set(8, 8, "RBMK Fuel")
		gpucomp.set(9, 10, "Fuel Rod Averages: ")
		gpucomp.set(9, 12, "Average Heat: " .. string.sub(tostring(average_heat), 1, 6) .. "°C" .. pad)
		gpucomp.set(9, 14, "Slow Flux: " .. string.sub(tostring(average_slow_flux), 1, 6) .. "cm²/s" .. pad)
		gpucomp.set(9, 15, "Fast Flux: " .. string.sub(tostring(average_fast_flux), 1, 6) .. "cm²/s" .. pad)
		gpucomp.set(9, 17, "Enrichment: ".. string.sub(tostring(average_depletion), 1, 6) .. "%" .. pad)
		gpucomp.set(9, 18, "Xenon Poisoning: " .. string.sub(tostring(average_xenon_poison), 1, 6) .. "%" .. pad)
		gpucomp.set(46, 8, "Fuel Rods:")
		for a, _ in pairs(rbmkfuel_table) do
			local b = funclib.inverse_mod(a, 5)
			gpucomp.fill((b*36) + 46, ((a-b*5)*7) + 8, 20, 7, " ")
			gpucomp.set((b*36) + 46, ((a-b*5)*7)+9, "Fuel Rod #: " .. a)
			gpucomp.set((b*36) + 46, ((a-b*5)*7)+10, "Heat: " .. string.sub(tostring(rbmkfuel_heat[a]), 1, 6) .. "°C" .. pad)
			gpucomp.set((b*36) + 46, ((a-b*5)*7)+11, "Slow Flux: " .. string.sub(tostring(rbmkfuel_Sflux[a]), 1, 6) .. "cm²/s" .. pad)
			gpucomp.set((b*36) + 46, ((a-b*5)*7)+12, "Fast Flux: " .. string.sub(tostring(rbmkfuel_Fflux[a]), 1, 6) .. "cm²/s" .. pad)
			gpucomp.set((b*36) + 46, ((a-b*5)*7)+13, "Depletion: " .. string.sub(tostring(rbmkfuel_Depletion[a]), 1, 6) .. "%" .. pad)
			gpucomp.set((b*36) + 46, ((a-b*5)*7)+14, "Xenon Level: " .. string.sub(tostring(rbmkfuel_Xenon[a]), 1, 6) .. "%" .. pad)
		end
	end
	if boiler_page and Boilers then
		--	local heat_1, water_1, water_max_1, steam_1, steam_max_1 = 0, 0, 0, 0, 0
		--	for _, v in pairs(rbmkfuel_table) do
		--		local heat, water, water_max, steam, steam_max, steam_type = getRodData("fuel", v)
		--		table.insert(rbmkboiler_heat, heat)
		--		table.insert(rbmkboiler_water, water)
		--		table.insert(rbmkboiler_maxW, water_max)
		--		table.insert(rbmkboiler_steam, steam)
		--		table.insert(rbmkboiler_maxS, steam_max)
		--		table.insert(rbmkboiler_type, steam_type)
		--		heat_1 = heat + heat_1
		--		water_1 = water + Sflux_1
		--		steam_1 = steam + Fflux_1
		--	end
		--	local average_heat = heat_1 / #rbmkfuel_table
		--	local average_slow_flux = Sflux_1 / #rbmkfuel_table
		--	local average_fast_flux = Fflux_1 / #rbmkfuel_table
		--	local average_depletion
		--	local average_xenon_poison
		draw_basics()
		gpucomp.setBackground(0x004900)
		gpucomp.fill(7, 7, 146, 40, " ")
		gpucomp.set(8, 8, "RBMK Boilers")
		--	for a, _ in pairs(rbmkfuel_table) do
		--		local b = funclib.inverse_mod(a, 5)
		--		gpucomp.fill((b*36) + 46, ((a-b*5)*7) + 8, 20, 7, " ")
		--		gpucomp.set((b*36) + 46, ((a-b*5)*7)+9, "Fuel Rod #: " .. a)
		--		gpucomp.set((b*36) + 46, ((a-b*5)*7)+10, "Heat: " .. string.sub(tostring(rbmkfuel_heat[a]), 1, 6) .. "°C" .. pad)
		--		gpucomp.set((b*36) + 46, ((a-b*5)*7)+11, "Slow Flux: " .. string.sub(tostring(rbmkfuel_Sflux[a]), 1, 6) .. "cm²/s" .. pad)
		--		gpucomp.set((b*36) + 46, ((a-b*5)*7)+12, "Fast Flux: " .. string.sub(tostring(rbmkfuel_Fflux[a]), 1, 6) .. "cm²/s" .. pad)
		--		gpucomp.set((b*36) + 46, ((a-b*5)*7)+13, "Depletion: " .. string.sub(tostring(rbmkfuel_Depletion[a]), 1, 6) .. "%" .. pad)
		--		gpucomp.set((b*36) + 46, ((a-b*5)*7)+14, "Xenon Level: " .. string.sub(tostring(rbmkfuel_Xenon[a]), 1, 6) .. "%" .. pad)
		--	end
	elseif boiler_page and not Boilers then
		draw_basics()
		gpucomp.setBackground(0x004900)
		gpucomp.fill(7, 7, 146, 40, " ")
		gpucomp.set(56, 30, "Boilers Disabled")
	end
	if control_page then
		while #ctrl_colors > 0 do
			table.remove(ctrl_colors)
		end
		for _, a in pairs(rbmkctrl_table) do
			local b = invoke(a, "getColor")
			if not(b == nil) then
				table.insert(ctrl_colors, b)
			else
				table.insert(ctrl_colors, "NONE")
			end
		end
		for i, v in pairs(rbmkctrl_table) do
			local a, b = invoke(v, "getInfo")
			table.insert(rbmkctrlheat_table, a)
			if not(b == ctrl_levels[i]) then
				invoke(v, "setLevel", ctrl_levels[i])
				desync[i] = true
			else
				desync[i] = false
			end
		end
		draw_basics()
		gpucomp.setBackground(0x004900)
		gpucomp.fill(7, 7, 146, 40, " ")
		gpucomp.set(8, 8, "RBMK Control Rods")
	end
	if cooler_page then
		for i, v in pairs(rbmkctrl_table) do
			local a, b = invoke(v, "getInfo")
			table.insert(rbmkctrlheat_table, a)
			if not(b == ctrl_levels[i]) then
				invoke(v, "setLevel", ctrl_levels[i])
				desync[i] = true
			else
				desync[i] = false
			end
		end
		draw_basics()
		gpucomp.setBackground(0x004900)
		gpucomp.fill(7, 7, 146, 40, " ")
		gpucomp.set(8, 8, "RBMK Coolers")
	end
	if outgasser_page then
		for i, v in pairs(rbmkctrl_table) do
			local a, b = invoke(v, "getInfo")
			table.insert(rbmkctrlheat_table, a)
			if not(b == ctrl_levels[i]) then
				invoke(v, "setLevel", ctrl_levels[i])
				desync[i] = true
			else
				desync[i] = false
			end
		end
		draw_basics()
		gpucomp.setBackground(0x004900)
		gpucomp.fill(7, 7, 146, 40, " ")
		gpucomp.set(8, 8, "RBMK Outgassers")
	end
	if heater_page then
		for i, v in pairs(rbmkctrl_table) do
			local a, b = invoke(v, "getInfo")
			table.insert(rbmkctrlheat_table, a)
			if not(b == ctrl_levels[i]) then
				invoke(v, "setLevel", ctrl_levels[i])
				desync[i] = true
			else
				desync[i] = false
			end
		end
		draw_basics()
		gpucomp.setBackground(0x004900)
		gpucomp.fill(7, 7, 146, 40, " ")
		gpucomp.set(8, 8, "RBMK Heaters")
	end
	local average_heat = getAverageRodData("fuel")
	if average_heat > CONFIG["maxheat"] and redstone_enabled then
		rs.setOutput({15, 15, 15, 15, 15, 15})
	elseif redstone_enabled then
		rs.setOutput({0, 0, 0, 0, 0, 0})
	end
	if AUTO then
		for i, c in pairs(rbmkctrlheat_table) do
			if c >= CONFIG["maxautoheat"] then
				for a in pairs(rbmkctrl_table) do
					ctrl_levels[a] = 0
				end
			else
				if c <= CONFIG["s1autoheat"] then
					if ctrl_levels[i] <= 75 then
						ctrl_levels[i] = ctrl_levels[i] + CONFIG["auto1basestep"]
					end
				elseif c <= CONFIG["s2autoheat"] then
					if ctrl_levels[i] <= 75 then
						ctrl_levels[i] = ctrl_levels[i] + CONFIG["auto2basestep"]
					end
				elseif c >= CONFIG["s4autoheat"] then
					ctrl_levels[i] = ctrl_levels[i] - CONFIG["auto1basestep"]
				elseif c >= CONFIG["s3autoheat"] then
					ctrl_levels[i] = ctrl_levels[i] - CONFIG["auto2basestep"]
				end
			end
		end
	end
	os.sleep(0.05)
end
gpucomp.setForeground(0x662400)
gpucomp.setBackground(0x000000)
while #rbmkctrl_table > 1 do
	table.remove(rbmkctrl_table)
end
while #rbmkfuel_table > 1 do
	table.remove(rbmkfuel_table)
end
while #energy_table > 1 do
	table.remove(energy_table)
end
if Boilers then
	while #rbmkboiler_table > 1 do
		table.remove(rbmkboiler_table)
	end
end
if Outgassers then
	while #rbmkoutgasser_table > 1 do
		table.remove(rbmkoutgasser_table)
	end
end
if Coolers then
	while #rbmkcooler_table > 1 do
		table.remove(rbmkcooler_table)
	end
end
print("Shutting down controller...")
os.sleep(2)
print("Cleaning up...")
e.ignore("touch", touch1)
e.ignore("interrupted", run)
os.sleep(1)
print("Process Terminated Successfully.")
-- EOF
