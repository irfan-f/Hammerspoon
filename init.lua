if hs.configdir and hs.configdir ~= "" then
  package.path = hs.configdir .. "/?.lua;" .. package.path
end

local config = require("config")
local displayEffects = require("display_effects")
local hkcap = require("hotkey_capture")

--- Apply config.lua to BrightnessPlus, init persisted state, bind toggle hotkey, optional menubar extra.
--- Safe to call more than once (e.g. LightFilter menubar path + BrightnessPlus.enabled).
local function setupBrightnessPlusFromConfig()
  if not (config.spoons.BrightnessPlus and spoon.BrightnessPlus) then
    return
  end
  local bp = config.spoons.BrightnessPlus
  if bp.defaultLevel ~= nil then
    spoon.BrightnessPlus.defaultBoost = bp.defaultLevel
  end
  spoon.BrightnessPlus:init()
  if bp.hotkey and bp.hotkey.mods and bp.hotkey.key then
    spoon.BrightnessPlus.hotkey = { mods = bp.hotkey.mods, key = bp.hotkey.key }
  end
  if bp.showMenubarExtra ~= nil then
    spoon.BrightnessPlus.showMenubarExtra = bp.showMenubarExtra
  end
  if type(bp.menubarShortTitle) == "string" then
    spoon.BrightnessPlus.menubarShortTitle = bp.menubarShortTitle
  end
  spoon.BrightnessPlus:bindHotkeys()
  spoon.BrightnessPlus:refreshExtraMenubar()
end

if config.console.clearOnStart then
  hs.console.clearConsole()
end

-- Optional: EmmyLua Spoon can be installed separately for IDE hints
pcall(function()
  hs.loadSpoon("EmmyLua")
end)

---------------------
-- Initial Settings
---------------------
-- Set the console to verbose
hs.logger.defaultLogLevel = config.logging.defaultLevel
-- Set hotkey alert to no show
hs.hotkey.alertDuration = config.ui.hotkeyAlertDuration
hs.alert.defaultStyle.atScreenEdge = config.ui.alertAtScreenEdge
hs.alert.defaultStyle.textStyle = { paragraphStyle = { alignment = config.ui.alertTextAlignment } }

---------------------
-- Menubar Manager (single tray icon)
---------------------
if config.spoons.MenubarManager and config.spoons.MenubarManager.enabled then
  hs.loadSpoon("MenubarManager")
end

displayEffects:startWatchers()

---------------------
-- Modal Control
---------------------
if config.spoons.ModalControl and config.spoons.ModalControl.enabled then
  hs.loadSpoon("ModalControl")
  local hk = config.spoons.ModalControl.hotkey
  if hk and hk.mods and hk.key then
    spoon.ModalControl.mods = hk.mods
    spoon.ModalControl.key = hk.key
  end
  spoon.ModalControl:start()
end

---------------------
-- Window Management
---------------------
if config.spoons.WindowManagement.enabled then
  hs.loadSpoon("WindowManagement")

  local wm = config.spoons.WindowManagement
  spoon.WindowManagement:setup(wm.gridSize, wm.marginH, wm.marginW)

  if wm.bindDefaultHotkeys then
    spoon.WindowManagement:bindDefaultHotkeys()
  end

  local mm = config.spoons.MenubarManager
  if mm and mm.enabled and spoon.MenubarManager then
    spoon.MenubarManager:registerAction({
      id = "windowManagementHotkeys",
      title = "Window hotkeys…",
      group = "Window management",
      order = 10,
      groupOrder = 15,
      fn = function()
        spoon.WindowManagement:showHotkeysPanel()
      end,
    })
  end
end

---------------------
-- Light Filter
---------------------
if config.spoons.LightFilter.enabled then
  hs.loadSpoon("LightFilter")
  -- Keep BrightnessPlus available for LightFilter actions, even if it is not shown in the menu.
  pcall(function()
    hs.loadSpoon("BrightnessPlus")
  end)

  local lf = config.spoons.LightFilter
  spoon.LightFilter:init()
  if lf.defaultWarmth ~= nil then
    spoon.LightFilter.defaultWarmth = lf.defaultWarmth
  end
  if lf.hotkey and lf.hotkey.mods and lf.hotkey.key then
    spoon.LightFilter.hotkey = { mods = lf.hotkey.mods, key = lf.hotkey.key }
  end
  if lf.showMenubarExtra ~= nil then
    spoon.LightFilter.showMenubarExtra = lf.showMenubarExtra
  end
  if type(lf.menubarShortTitle) == "string" then
    spoon.LightFilter.menubarShortTitle = lf.menubarShortTitle
  end
  spoon.LightFilter:bindHotkeys()
  spoon.LightFilter:refreshExtraMenubar()
  if spoon.MenubarManager and lf.menuTitle then
    spoon.MenubarManager:registerToggle({
      id = "lightFilter",
      title = lf.menuTitle,
      group = "Light filter",
      order = 10,
      groupOrder = 10,
      hotkey = hkcap.formatMenubarHotkey(spoon.LightFilter.hotkey),
      get = function()
        return spoon.LightFilter:isEnabled()
      end,
      set = function(enabled)
        spoon.LightFilter:setEnabled(enabled)
      end,
      status = function()
        if not spoon.LightFilter:isEnabled() then
          return ""
        end
        return tostring(spoon.LightFilter:getWarmth()) .. "%"
      end,
    })
  end

  if spoon.MenubarManager and lf.adjustTitle then
    spoon.MenubarManager:registerAction({
      id = "lightFilterAdjust",
      title = lf.adjustTitle,
      group = "Light filter",
      order = 20,
      groupOrder = 10,
      fn = function()
        spoon.LightFilter:showOptions()
      end,
    })
  end

  -- BrightnessPlus is pcall-loaded above for menubar boost + LightFilter mutual exclusion.
  -- When only LightFilter is enabled, config often sets BrightnessPlus.enabled = false; still bind hotkey.
  if spoon.BrightnessPlus and lf.brightnessBoostTitle then
    setupBrightnessPlusFromConfig()
  end
end

---------------------
-- Brightness boost (MenubarManager; separate group from Light filter)
if config.spoons.LightFilter and config.spoons.LightFilter.brightnessBoostTitle then
  local lf = config.spoons.LightFilter
  local brightnessGroup = (type(lf.brightnessMenubarGroup) == "string" and lf.brightnessMenubarGroup ~= "")
      and lf.brightnessMenubarGroup
    or "Brightness boost"
  local brightnessGroupOrder = tonumber(lf.brightnessMenubarGroupOrder) or 11

  local adjustBrightnessTitle = "Settings"
  if config.spoons.BrightnessPlus and type(config.spoons.BrightnessPlus.adjustTitle) == "string" then
    adjustBrightnessTitle = config.spoons.BrightnessPlus.adjustTitle
  end

  if spoon.MenubarManager and lf.brightnessBoostTitle then
    spoon.MenubarManager:registerToggle({
      id = "brightnessBoost",
      title = lf.brightnessBoostTitle,
      group = brightnessGroup,
      order = 10,
      groupOrder = brightnessGroupOrder,
      hotkey = spoon.BrightnessPlus and hkcap.formatMenubarHotkey(spoon.BrightnessPlus.hotkey) or nil,
      get = function()
        return spoon.BrightnessPlus and spoon.BrightnessPlus:isEnabled() or false
      end,
      set = function(enabled)
        if not spoon.BrightnessPlus then
          hs.alert.show("BrightnessPlus not available")
          return
        end
        spoon.BrightnessPlus:setEnabled(enabled)
      end,
      status = function()
        if not spoon.BrightnessPlus or not spoon.BrightnessPlus:isEnabled() then
          return ""
        end
        return tostring(spoon.BrightnessPlus:getBoost()) .. "%"
      end,
    })
  end

  if spoon.MenubarManager then
    spoon.MenubarManager:registerAction({
      id = "brightnessBoostAdjust",
      title = adjustBrightnessTitle,
      group = brightnessGroup,
      order = 20,
      groupOrder = brightnessGroupOrder,
      fn = function()
        if not spoon.BrightnessPlus then
          hs.alert.show("BrightnessPlus not available")
          return
        end
        spoon.BrightnessPlus:showOptions()
      end,
    })
  end
end

if config.spoons.Caffeinate.enabled then
  hs.loadSpoon("Caffeinate")

  local caf = config.spoons.Caffeinate
  spoon.Caffeinate:init()
  if caf.hotkey and caf.hotkey.mods and caf.hotkey.key then
    spoon.Caffeinate.hotkey = { mods = caf.hotkey.mods, key = caf.hotkey.key }
  end
  spoon.Caffeinate:bindHotkeys()
  if spoon.MenubarManager and caf.menuTitle then
    spoon.MenubarManager:registerToggle({
      id = "caffeinateDisplayIdle",
      title = caf.menuTitle,
      group = "Caffeinate",
      order = 10,
      groupOrder = 20,
      hotkey = hkcap.formatMenubarHotkey(spoon.Caffeinate.hotkey),
      get = function()
        return spoon.Caffeinate:isEnabled()
      end,
      set = function(enabled)
        spoon.Caffeinate:setEnabled(enabled)
      end,
    })

    spoon.MenubarManager:registerAction({
      id = "caffeinateSettings",
      title = (type(caf.settingsTitle) == "string" and caf.settingsTitle ~= "") and caf.settingsTitle or "Settings",
      group = "Caffeinate",
      order = 20,
      groupOrder = 20,
      fn = function()
        spoon.Caffeinate:showSettings()
      end,
    })
  end
end

---------------------
-- BrightnessPlus
---------------------
if config.spoons.BrightnessPlus and config.spoons.BrightnessPlus.enabled then
  hs.loadSpoon("BrightnessPlus")
  setupBrightnessPlusFromConfig()
end

---------------------
-- OCRTextExtractor
---------------------
if config.spoons.OCRTextExtractor and config.spoons.OCRTextExtractor.enabled then
  hs.loadSpoon("OCRTextExtractor")
  local o = config.spoons.OCRTextExtractor
  if o.hotkey and o.hotkey.mods and o.hotkey.key then
    spoon.OCRTextExtractor.hotkey = { mods = o.hotkey.mods, key = o.hotkey.key }
  end
  if o.showMenubarItem ~= nil then
    spoon.OCRTextExtractor.showMenubarItem = o.showMenubarItem
  end
  if type(o.menubarTitle) == "string" then
    spoon.OCRTextExtractor.menubarTitle = o.menubarTitle
  end
  if type(o.notificationTitle) == "string" then
    spoon.OCRTextExtractor.notificationTitle = o.notificationTitle
  end
  if type(o.outputAction) == "string" then
    spoon.OCRTextExtractor.outputAction = o.outputAction
  end
  if type(o.inputAction) == "string" then
    spoon.OCRTextExtractor.inputAction = o.inputAction
  end
  if type(o.outputFolder) == "string" then
    spoon.OCRTextExtractor.outputFolder = o.outputFolder
  end
  spoon.OCRTextExtractor:bindHotkeys()
  spoon.OCRTextExtractor:start()

  if spoon.MenubarManager then
    spoon.MenubarManager:registerAction({
      id = "ocrStart",
      title = "Capture Text from Image",
      group = "OCR",
      order = 5,
      groupOrder = 30,
      hotkey = hkcap.formatMenubarHotkey(spoon.OCRTextExtractor.hotkey),
      fn = function()
        spoon.OCRTextExtractor:runDefaultInputFlow()
      end,
    })

    spoon.MenubarManager:registerAction({
      id = "ocrSettings",
      title = "Settings",
      group = "OCR",
      order = 20,
      groupOrder = 30,
      fn = function()
        spoon.OCRTextExtractor:showSettingsChooser()
      end,
    })
  end
end

---------------------
-- ActivityAdvisor
---------------------
if config.spoons.ActivityAdvisor and config.spoons.ActivityAdvisor.enabled then
  hs.loadSpoon("ActivityAdvisor")
  local aa = config.spoons.ActivityAdvisor
  if tonumber(aa.watchCpuPercent) then
    spoon.ActivityAdvisor.watchCpuPercent = tonumber(aa.watchCpuPercent)
  end
  if tonumber(aa.pruneBackgroundCpuPercent) then
    spoon.ActivityAdvisor.pruneBackgroundCpuPercent = tonumber(aa.pruneBackgroundCpuPercent)
  end
  if tonumber(aa.pruneMemoryMb) then
    spoon.ActivityAdvisor.pruneMemoryMb = tonumber(aa.pruneMemoryMb)
  end
  if aa.hotkey and aa.hotkey.mods and aa.hotkey.key then
    spoon.ActivityAdvisor.hotkey = { mods = aa.hotkey.mods, key = aa.hotkey.key }
  end
  spoon.ActivityAdvisor:init()
  spoon.ActivityAdvisor:bindHotkeys()

  local menubarTitle = (type(aa.menubarTitle) == "string" and aa.menubarTitle ~= "") and aa.menubarTitle
      or "Activity advisor…"
  local group = (type(aa.group) == "string" and aa.group ~= "") and aa.group or "Activity"
  local groupOrder = tonumber(aa.groupOrder) or 35

  if spoon.MenubarManager then
    spoon.MenubarManager:registerAction({
      id = "activityAdvisorShow",
      title = menubarTitle,
      group = group,
      order = 10,
      groupOrder = groupOrder,
      hotkey = hkcap.formatMenubarHotkey(spoon.ActivityAdvisor.hotkey),
      fn = function()
        spoon.ActivityAdvisor:showAdvisor()
      end,
    })
  end
end