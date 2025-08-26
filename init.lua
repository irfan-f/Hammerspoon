-- Clear the Hammerspoon console
hs.console.clearConsole()

-- Establish intellisense for Hammerspoon
local ipc = require('hs.ipc')
ipc.cliInstall("/opt/homebrew")

-- Load the EmmyLua which will provide intellisense for Hammerspoon based on docs
hs.loadSpoon('EmmyLua')

---------------------
-- Initial Settings
---------------------
-- Set the console to verbose
hs.logger.defaultLogLevel = 'info'
-- Set hotkey alert to no show
hs.hotkey.alertDuration = 0
hs.alert.defaultStyle.atScreenEdge = 0
hs.alert.defaultStyle.textStyle = { paragraphStyle = { alignment = "center" } }

---------------------
-- Reload Configuration
---------------------
-- Load the Spoon
hs.loadSpoon('ReloadConfiguration')

-- Bind the hotkeys
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "up", "Live Reload - Toggle", nil, function()
  spoon.ReloadConfiguration:toggle()
end)

-- On Reload
-- spoon.ReloadConfiguration:start()

-- Misc. settings

---------------------
-- Window Management
---------------------
-- Load the Spoon
hs.loadSpoon('WindowManagement')

-- Setup the Spoon
spoon.WindowManagement:setup(2, 0, 0)

-- Bind the hotkeys
spoon.WindowManagement:bindDefaultHotkeys()

-- Misc. settings

---------------------
-- Window Hints
  -- not currently used
---------------------
-- hs.hints.showTitleThresh = 5
-- hs.hotkey.bind({ "alt", "shift" }, "A", "Hint - Show", nil, function()
--   hs.hints.windowHints(nil, function() end, true)
-- end)

---------------------
-- Keybind Search
---------------------
-- Load the Spoon
hs.loadSpoon('KeybindSearch')

-- Bind the hotkeys
hs.hotkey.bind({ "cmd", "option", "ctrl" }, "space", function() spoon.KeybindSearch:show() end)

---------------------
-- Light Filter
---------------------
-- Load the Spoon
hs.loadSpoon('LightFilter')

hs.loadSpoon('Caffeinate')
