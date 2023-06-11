
-- CONFIG
local CONFIG = {
  maxheat = 1500,
  bmaxsteam = 1000000,
  bmaxwater = 10000,
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
err_h = {}
local function Fatal_err(err)
  print(debug.traceback("FATAL ERROR: " .. err))
  return nil
end
local function Warn_err(err)
  gpucomp.setForeground(0xFFFF00)
  print("WARN: " .. err)
  gpucomp.setForeground(0xFFFFFF)
  return nil
end
local function l_module(module, sev)
  if sev == 1 then
    local stat, a = xpcall(function(module1) return require(tostring(module1)) end, Warn_err, module)
    if stat then
      return a
    else
      os.exit()
    end
  elseif sev == 2 then
    local stat, a = xpcall(function(module1) return require(tostring(module1)) end, Fatal_err, module)
    if stat then
      return a
    else
      os.exit()
    end
  end
end

local component = l_module("component", 2)
local e = l_module("event", 2)
local gpucomp = component.gpu
local rs = component.redstone
local invoke = component.invoke

-- Variable assignment.
local rbmkctrl = "rbmk_control_rod"
local rbmkfuel = "rbmk_fuel_rod"
local energy = "ntm_energy_storage"
local rbmkboiler = "rbmk_boiler"
local rbmkcooler = "rbmk_cooler"
local rbmkoutgasser = "rbmk_outgasser"
local rbmkctrl_table = {}
local rbmkfuel_table = {}
local ctrl_levels = {}
local ctrl_colors = {}
local energy_table = {}
local rbmkboiler_table = {}
local rbmkheat_table = {}
local rbmkcooler_table = {}
local rbmkoutgasser_table = {}
local desync = {}
local running = true
local redstone_enabled
local Coolers
local Outgassers
local Boilers
local AUTO

-- Define functions needed by the program.
function touch(x, y)
  for i, _ in pairs(ctrl_levels) do
    if tonumber(x) == 120 and tonumber(y) == tonumber(5 + (i * 3)) then
      ctrl_levels[i] = ctrl_levels[i] + CONFIG["basestep"]
    elseif tonumber(x) == 137 and tonumber(y) == tonumber(5 + (i * 3)) then
      ctrl_levels[i] = ctrl_levels[i] - CONFIG["basestep"]
    end
  end
  if x >= 108 and x <= 115 and y >= 13 and y <= 16 then
    for i, v in pairs(ctrl_colors) do
      if v == "RED" then
        ctrl_levels[i] = ctrl_levels[i] - CONFIG["basestep"]
      end
    end
  elseif x >= 108 and x <= 115 and y >= 17 and y <= 20 then
    for i, v in pairs(ctrl_colors) do
      if v == "YELLOW" then
        ctrl_levels[i] = ctrl_levels[i] - CONFIG["basestep"]
      end
    end
  elseif x >= 108 and x <= 115 and y >= 21 and y <= 24 then
    for i, v in pairs(ctrl_colors) do
      if v == "GREEN" then
        ctrl_levels[i] = ctrl_levels[i] - CONFIG["basestep"]
      end
    end
  elseif x >= 108 and x <= 115 and y >= 25 and y <= 28 then
    for i, v in pairs(ctrl_colors) do
      if v == "BLUE" then
        ctrl_levels[i] = ctrl_levels[i] - CONFIG["basestep"]
      end
    end
  elseif x >= 108 and x <= 115 and y >= 29 and y <= 32 then
    for i, v in pairs(ctrl_colors) do
      if v == "PURPLE" then
        ctrl_levels[i] = ctrl_levels[i] - CONFIG["basestep"]
      end
    end
  elseif x >= 93 and x <= 100 and y >= 13 and y <= 16 then
    for i, v in pairs(ctrl_colors) do
      if v == "RED" then
        ctrl_levels[i] = ctrl_levels[i] + CONFIG["basestep"]
      end
    end
  elseif x >= 93 and x <= 100 and y >= 17 and y <= 20 then
    for i, v in pairs(ctrl_colors) do
      if v == "YELLOW" then
        ctrl_levels[i] = ctrl_levels[i] + CONFIG["basestep"]
      end
    end
  elseif x >= 93 and x <= 100 and y >= 21 and y <= 24 then
    for i, v in pairs(ctrl_colors) do
      if v == "GREEN" then
        ctrl_levels[i] = ctrl_levels[i] + CONFIG["basestep"]
      end
    end
  elseif x >= 93 and x <= 100 and y >= 25 and y <= 28 then
    for i, v in pairs(ctrl_colors) do
      if v == "BLUE" then
        ctrl_levels[i] = ctrl_levels[i] + CONFIG["basestep"]
      end
    end
  elseif x >= 93 and x <= 100 and y >= 29 and y <= 32 then
    for i, v in pairs(ctrl_colors) do
      if v == "PURPLE" then
        ctrl_levels[i] = ctrl_levels[i] + CONFIG["basestep"]
      end
    end
  elseif x >= 9 and x <= 19 and y >= 6 and y <= 11 then
    if AUTO then
      AUTO = false
    else
      AUTO = true
    end
  elseif x >= 9 and x <= 19 and y >= 12 and y <= 17 then
    for i, _ in pairs(rbmkctrl_table) do
      ctrl_levels[i] = 0
    end
  end
end

-- User Confirmation.
do
  do
    print("Enable redstone output? Y/N")
    local user1 = io.read()
    if user1 == "y" or user1 == "Y" then
      redstone_enabled = true
    elseif user1 == "n" or user1 == "N" then
      redstone_enabled = false
    else
      Warn_err("INVALID_CHAR")
      os.exit()
    end
  end
  do
    print("Are there boiler columns present in the reactor? Y/N")
    local user1 = io.read()
    if user1 == "y" or user1 == "Y" then
      Boilers = true
    elseif user1 == "n" or user1 == "N" then
      Boilers = false
    else
      Warn_err("INVALID_CHAR")
      os.exit()
    end
    print("Are there cooler columns present in the reactor? Y/N")
    local user2 = io.read()
    if user2 == "y" or user2 == "Y" then
      Coolers = true
    elseif user2 == "n" or user2 == "N" then
      Coolers = false
    else
      Warn_err("INVALID_CHAR")
      os.exit()
    end
    print("Are there irradiation columns present in the reactor? Y/N")
    local user3 = io.read()
    if user3 == "y" or user3 == "Y" then
      Outgassers = true
    elseif user3 == "n" or user3 == "N" then
      Outgassers = false
    else
      Warn_err("INVALID_CHAR")
      os.exit()
    end
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
gpucomp.setBackground(0x333333)
gpucomp.fill(1, 1, 170, 60, " ")
gpucomp.setBackground(0x666666)
gpucomp.fill(119, 7, 34, #rbmkctrl_table * 3 + 1, " ")
gpucomp.setBackground(0x777720)
gpucomp.fill(8, 11, 12, 7, " ")
gpucomp.setBackground(0x330000)
gpucomp.fill(9, 12, 10, 5, " ")
gpucomp.set(12, 14, "AZ-5")
for a, _ in pairs(rbmkctrl_table) do
  gpucomp.setBackground(0x330000)
  gpucomp.set(120, 5 + a * 3, "▲")
  gpucomp.set(137, 5 + a * 3, "▼")
  gpucomp.setBackground(0x666666)
  gpucomp.set(122, 5 + a * 3, "Control Rod #" .. a)
end
gpucomp.setBackground(0x330000)
gpucomp.fill(93, 13, 7, 3, " ")
gpucomp.fill(93, 17, 7, 3, " ")
gpucomp.fill(93, 21, 7, 3, " ")
gpucomp.fill(93, 25, 7, 3, " ")
gpucomp.fill(93, 29, 7, 3, " ")
gpucomp.fill(108, 13, 7, 3, " ")
gpucomp.fill(108, 17, 7, 3, " ")
gpucomp.fill(108, 21, 7, 3, " ")
gpucomp.fill(108, 25, 7, 3, " ")
gpucomp.fill(108, 29, 7, 3, " ")
gpucomp.set(96, 14, "▲")
gpucomp.set(96, 22, "▲")
gpucomp.set(96, 30, "▲")
gpucomp.set(96, 18, "▲")
gpucomp.set(96, 26, "▲")
gpucomp.set(111, 18, "▼")
gpucomp.set(111, 26, "▼")
gpucomp.set(111, 14, "▼")
gpucomp.set(111, 22, "▼")
gpucomp.set(111, 30, "▼")
gpucomp.setBackground(0x662400)
gpucomp.fill(101, 13, 6, 3, " ")
gpucomp.set(102, 14, "RED")
gpucomp.setBackground(0x99B600)
gpucomp.fill(101, 17, 6, 3, " ")
gpucomp.set(101, 18, "YELLOW")
gpucomp.setBackground(0x339240)
gpucomp.fill(101, 21, 6, 3, " ")
gpucomp.set(101, 22, "GREEN")
gpucomp.setBackground(0x3349C0)
gpucomp.fill(101, 25, 6, 3, " ")
gpucomp.set(101, 26, "BLUE")
gpucomp.setBackground(0x6649C0)
gpucomp.fill(101, 29, 6, 3, " ")
gpucomp.set(101, 30, "PURPLE")
function touch1(_, _, x, y)
  xpcall(touch, Warn_err, x, y)
end
function run()
  running = false
end
for _, a in pairs(rbmkctrl_table) do
  local b = invoke(a, "getColor")
  if not(b == nil) then
    table.insert(ctrl_colors, b)
  else
    table.insert(ctrl_colors, "NONE")
  end
end
for _ in pairs(rbmkctrl_table) do
  table.insert(desync, false)
end
e.listen("touch", touch1)
e.listen("interrupted", run)
while true do
  if not running then
    break
  end
  while #rbmkheat_table > 0 do
    table.remove(rbmkheat_table)
  end
  for i, v in pairs(rbmkctrl_table) do
    local a, b = invoke(v, "getInfo")
    table.insert(rbmkheat_table, a)
    if not(b == ctrl_levels[i]) then
      invoke(v, "setLevel", ctrl_levels[i])
      desync[i] = true
    else
      desync[i] = false
    end
  end
  local available3 = component.isAvailable(energy)
  if not available3 then
    energy2 = "N/A"
    stor_energy2 = "N/A"
    energy_t = "N/A"
    energy_perc = "N/A"
  else
    local energy1
    local energy2 = 0
    local stor_energy_1 = 0
    local stor_energy_2 = 0
    local stor_energy_4 = 0
    local stor_energy_5 = 0
    local stor_energy_3 = 0
    for _, v in pairs(energy_table) do
      energy1, stor_energy_1 = invoke(v, "getInfo")
      energy2 = energy2 + energy1
      stor_energy_2 = stor_energy_2 + stor_energy_1
      stor_energy_4 = invoke(v, "getEnergyStored")
      stor_energy_3 = stor_energy_3 + stor_energy_1
      stor_energy_5 = stor_energy_5 + stor_energy_4
    end
    energy_perc = (stor_energy_2 / energy2) * 100
    stor_energy_1 = stor_energy_3 / #energy_table
    stor_energy_2 = stor_energy_5 / #energy_table
    energy_t = stor_energy_2 - stor_energy_1
  end
  local available1 = component.isAvailable(rbmkfuel)
  local available2 = component.isAvailable(rbmkctrl)
  if available1 and available2 then
    local heat_2 = 0
    local FFlux_2 = 0
    local SFlux_2 = 0
    local Xenon_2 = 0
    local Depletion_2 = 0
    local bheat_2 = 0
    local bsteam_2 = 0
    local bwater_2 = 0
    for _, address in pairs(rbmkfuel_table) do
      local heat_1, SFlux_1, FFlux_1, Depletion_1, Xenon_1 = invoke(address, "getInfo")
      heat_2 = heat_2 + heat_1
      FFlux_2 = FFlux_2 + FFlux_1
      SFlux_2 = SFlux_2 + SFlux_1
      if not (Depletion_1 == "N/A") then
        Depletion_2 = Depletion_2 + Depletion_1
      else
        Depletion_1_avg = "NO FUEL"
      end
      if not (Xenon_1 == "N/A") then
        Xenon_2 = Xenon_2 + Xenon_1
      else
        Xenon_1_avg = "NO FUEL"
      end
    end
    if Boilers then
      for _, address in pairs(rbmkboiler_table) do
        local bheat_1, bsteam_1, _, bwater_1, _ = invoke(address, "getInfo")
        bheat_2 = bheat_2 + bheat_1
        bsteam_2 = bsteam_2 + bsteam_1
        bwater_2 = bwater_2 + bwater_1
      end
      bheat_1_avg = bheat_2 / #rbmkboiler_table
      bsteam_1_avg = bsteam_2 / #rbmkboiler_table
      bwater_1_avg = bwater_2 / #rbmkboiler_table
    else
      bheat_1_avg = "N/A"
      bsteam_1_avg = "N/A"
      bwater_1_avg = "N/A"
    end
    heat_1_avg = heat_2 / #rbmkfuel_table
    FFlux_1_avg = FFlux_2 / #rbmkfuel_table
    SFlux_1_avg = SFlux_2 / #rbmkfuel_table
    if not(Depletion_1_avg == "NO FUEL") then
      Depletion_1_avg = Depletion_2 / #rbmkfuel_table
    end
    if not(Xenon_1_avg == "NO FUEL") then
      Xenon_1_avg = Xenon_2 / #rbmkfuel_table
    end
  end
  gpucomp.setForeground(0xffffff)
  gpucomp.setBackground(0x666666)
  gpucomp.fill(1, 1, 19, 3, " ")
  gpucomp.set(2, 2, os.date())
  gpucomp.fill(22, 3, 33, 23, " ")
  gpucomp.setBackground(0x888888)
  gpucomp.fill(23, 18, 22, 3, " ")
  gpucomp.setBackground(0x666666)
  gpucomp.set(23, 13, "POWER STORAGE STATS:")
  gpucomp.set(23, 15, "Max Storage:")
  gpucomp.set(23, 16, "Stored Energy:")
  gpucomp.set(23, 23, "Energy/t:")
  gpucomp.set(23, 24, "Energy/s:")
  gpucomp.set(37, 15, tostring(energy2) .. "HE")
  gpucomp.set(37, 16, tostring(stor_energy2) .. "HE")
  if energy_t == "N/A" then
    gpucomp.set(33, 23, "N/A " .. "HE/t")
    gpucomp.set(33, 24, "N/A " .. "HE/s")
  else
    gpucomp.set(33, 23, tostring(energy_t / 2) .. "HE/t")
    gpucomp.set(33, 24, tostring(energy_t * 10) .. "HE/s")
  end
  gpucomp.setBackground(0x222222)
  gpucomp.fill(24, 19, 20, 1, " ")
  gpucomp.setBackground(0x103a1f)
  if not(energy_perc == "N/A") then
    gpucomp.fill(23, 19, energy_perc / 5, 1, " ")
  end
  gpucomp.setBackground(0x666666)
  gpucomp.set(23, 21, string.sub(tostring(energy_perc),1,6) .. "%")
  for a, v in pairs(ctrl_levels) do
    gpucomp.set(127, 6 + a * 3, string.sub(tostring(v),1,6) .. "% ")
  end
  gpucomp.set(23, 4, "RBMK FUEL ROD AVERAGES:")
  gpucomp.set(23, 6, "Heat:")
  gpucomp.set(23, 7, "Fast Flux:")
  gpucomp.set(23, 8, "Slow Flux:")
  gpucomp.set(29, 6, string.sub(tostring(heat_1_avg), 1, 6) .. "°C")
  gpucomp.set(34, 7, string.sub(tostring(FFlux_1_avg),1,6))
  gpucomp.set(34, 8, string.sub(tostring(SFlux_1_avg),1,6))
  gpucomp.set(23, 9, "Depletion:")
  gpucomp.set(23, 10, "Xenon Level:")
  if Depletion_1_avg == "NO FUEL" then
    gpucomp.set(34, 9, tostring("NO FUEL"))
  else
    gpucomp.set(34, 9, string.sub(tostring(Depletion_1_avg * 100),1,6) .. "%")
  end
  if Xenon_1_avg == "NO FUEL" then
    gpucomp.set(36, 10, tostring("NO FUEL"))
  else
    gpucomp.set(36, 10, string.sub(tostring(Xenon_1_avg),1,6) .. "%")
  end
  if Boilers then
    gpucomp.fill(57, 3, 33, 23, " ")
    gpucomp.set(58, 4, "BOILER COLUMN AVERAGES:")
    gpucomp.set(58, 6, "Water:")
    gpucomp.set(58, 7, "Max Water:")
    gpucomp.set(69, 7, tostring(CONFIG["bmaxwater"]) .. "mB")
    gpucomp.set(58, 9, "Steam:")
    gpucomp.set(58, 10, "Max Steam:")
    gpucomp.set(69, 10, tostring(CONFIG["bmaxsteam"]) .. "mB")
    gpucomp.set(58, 12, "Heat:")
    gpucomp.set(65, 6, bwater_1_avg .. "mB")
    gpucomp.set(65, 9, bsteam_1_avg .. "mB")
    gpucomp.set(64, 12, string.sub(tostring(bheat_1_avg), 1, 5) .. "°C")
    gpucomp.setBackground(0x888888)
    gpucomp.fill(57, 14, 22, 9, " ")
    gpucomp.set(58, 14, "Water:")
    gpucomp.set(58, 17, "Steam:")
    gpucomp.set(58, 20, "Heat:")
    gpucomp.setBackground(0x222222)
    gpucomp.fill(58, 15, 20, 1, " ")
    gpucomp.setBackground(0x3349C0)
    gpucomp.fill(58, 15, (bwater_1_avg / CONFIG["bmaxwater"]) * 20, 1, " ")
    gpucomp.setBackground(0x222222)
    gpucomp.fill(58, 18, 20, 1, " ")
    gpucomp.setBackground(0xFFDBFF)
    gpucomp.fill(58, 18, (bsteam_1_avg / CONFIG["bmaxsteam"]) * 20, 1, " ")
    gpucomp.setBackground(0x222222)
    gpucomp.fill(58, 21, 20, 1, " ")
    gpucomp.setBackground(0x662400)
    gpucomp.fill(58, 21, (bheat_1_avg / CONFIG["bmaxheat"]) * 20, 1, " ")
  end
  gpucomp.setBackground(0x666666)
  if Outgassers then
    local gas, gasMax, progress
    gpucomp.fill(22, 27, 33, 23, " ")
    gpucomp.set(23, 28, "RBMK OUTGASSERS")
    for a, addr in pairs(rbmkoutgasser_table) do
      gas, gasMax, progress = invoke(addr, "getInfo")
      gpucomp.set(23, 28 + a*2, "OUTGASSER COLUMN #" .. a)
    end
  end

  if Coolers then
    gpucomp.fill(57, 27, 33, 23, " ")
  end
  for a, v in pairs(ctrl_colors) do
    if v == "RED" then
      gpucomp.setBackground(0x662400)
    elseif v == "YELLOW" then
      gpucomp.setBackground(0x99B600)
    elseif v == "GREEN" then
      gpucomp.setBackground(0x339240)
    elseif v == "BLUE" then
      gpucomp.setBackground(0x3349C0)
    elseif v == "PURPLE" then
      gpucomp.setBackground(0x6649C0)
    else
      gpucomp.setBackground(0x666666)
    end
    gpucomp.set(139, 5 + a * 3, "Color: " .. v)
  end
  gpucomp.setBackground(0x666666)
  if heat_1_avg > CONFIG["maxheat"] and redstone_enabled then
    rs.setOutput({15, 15, 15, 15, 15, 15})
  else
    rs.setOutput({0, 0, 0, 0, 0, 0})
  end
  gpucomp.setBackground(0x777720)
  gpucomp.fill(8, 5, 12, 7, " ")
  if AUTO then
    gpucomp.setBackground(0x103a1f)
    for i, c in pairs(rbmkheat_table) do
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
  elseif not AUTO then
    gpucomp.setBackground(0x330000)
  end
  gpucomp.fill(9, 6, 10, 5, " ")
  gpucomp.set(12, 8, "AUTO")
  os.sleep(0.001)
end
gpucomp.setForeground(0x662400)
gpucomp.setBackground(0x000000)
print("Shutting down reactor...")
for _, a in pairs(rbmkctrl_table) do
  invoke(a, "setLevel", 0)
end
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
os.sleep(2)
print("Cleaning up...")
e.ignore("touch", touch1)
e.ignore("interrupted", run)
os.sleep(1)
print("Process Terminated Successfully.")
-- EOF