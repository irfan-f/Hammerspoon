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
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "up", "Live Reload - Toggle", nil, function()
  spoon.ReloadConfiguration:toggle()
end)

-- On Reload
spoon.ReloadConfiguration:start()

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
---------------------
hs.hints.showTitleThresh = 5
hs.hotkey.bind({"alt", "shift"}, "A", "Hint - Show", nil, function()
  hs.hints.windowHints(nil, function() end, true)
end)

---------------------
-- Keybind Search
---------------------
-- Load the Spoon
hs.loadSpoon('KeybindSearch')

-- Bind the hotkeys
hs.hotkey.bind({"cmd", "option", "ctrl"}, "space", function() spoon.KeybindSearch:show() end)


---------------------
-- Playing Around
---------------------
local caffeine = hs.menubar.new()
local function setCaffeineDisplay(state)
    if state then
        caffeine:setTitle("AWAKE")
    else
        caffeine:setTitle("SLEEPY")
    end
end

local function caffeineClicked()
    setCaffeineDisplay(hs.caffeinate.toggle("displayIdle"))
end

if caffeine then
    caffeine:setClickCallback(caffeineClicked)
    setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
end

-- local ok,result = hs.applescript('tell Application "Spotify" to artist of the current track as string')
-- hs.alert.show(result)

-- hs.urlevent.bind("someAlert", function(eventName, params)
--   hs.alert.show("Received someAlert")
-- end)

--- Pasteboard workaround
-- hs.hotkey.bind({"cmd", "alt"}, "V", function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

-- wifiWatcher = nil
-- homeSSID = "MyHomeNetwork"
-- lastSSID = hs.wifi.currentNetwork()

-- function ssidChangedCallback()
--     newSSID = hs.wifi.currentNetwork()

--     if newSSID == homeSSID and lastSSID ~= homeSSID then
--         -- We just joined our home WiFi network
--         hs.audiodevice.defaultOutputDevice():setVolume(25)
--     elseif newSSID ~= homeSSID and lastSSID == homeSSID then
--         -- We just departed our home WiFi network
--         hs.audiodevice.defaultOutputDevice():setVolume(0)
--     end

--     lastSSID = newSSID
-- end

-- wifiWatcher = hs.wifi.watcher.new(ssidChangedCallback)
-- wifiWatcher:start()


