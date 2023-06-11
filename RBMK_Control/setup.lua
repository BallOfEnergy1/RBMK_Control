
-- Installation program for RBMK_control.

local component = require("component")
local shell = require("shell")
if component.isAvailable("internet") then
	print("Starting Install...")
	require("filesystem").makeDirectory("/RBMK_Control")
	shell.execute("wget", nil, "http://raw.githubusercontent.com/BallOfEnergy1/RBMK_Control/master/RBMK_Control/funclib.lua", "/lib/funclib.lua", "-f")
	shell.execute("wget", nil, "http://raw.githubusercontent.com/BallOfEnergy1/RBMK_Control/master/RBMK_Control/RBMK_Monitor.lua", "/RBMK_Control/RBMK_Monitor.lua", "-f")
	shell.execute("wget", nil, "http://raw.githubusercontent.com/BallOfEnergy1/RBMK_Control/master/RBMK_Control/README.txt", "/RBMK_Control/README.txt", "-f")
	print("Verifying integrity of files...")
	local a = io.open("/lib/funclib.lua")
	local b = io.open("/RBMK_Control/RBMK_Monitor.lua")
	local c = io.open("/RBMK_Control/README.txt")
	if a:read() == "" then
		print("Failed to fetch libraries, rerun setup.")
	end
	if b:read() == "" then
		print("Failed to fetch primary program, rerun setup.")
	end
	if c:read() == "" then
		print("Failed to fetch documentation, rerun setup.")
	end
	if not(a:read() == "") and not(b:read() == "") and not(c:read() == "") then
		print("Installation complete, make sure to read the README.txt for help.")
	end
else
	print("Internet card is required to install.")
end