--- === ReloadConfiguration ===
---
--- Provides an easy way to start and stop watching the Hammerspoon directory to live reload the configuration.
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "ReloadConfiguration"
obj.version = "0.1.0"
obj.author = "Irfan F."
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Private variables
local _watcher = nil

-- Menubar
--- @type hs.menubar | nil
local menubar
-- Menubar message strings
local menubarPrefix = "HS reload: "
local menubarRefreshIcon = hs.image.systemImageNames.RefreshTemplate
local menubarStopIcon = hs.image.systemImageNames.StopProgressTemplate

-- Menubar click callback
local function menubarClicked()
  obj:toggle()
end



--- ReloadConfiguration:start()
--- Method
--- Start watching the Hammerspoon directory to live reload the configuration
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
function obj:start()
  -- If the watcher is already running, stop it
  if _watcher ~= nil then
    self:stop()
  end

  -- Create a new watcher and start it
  _watcher = hs.pathwatcher.new(os.getenv('HOME') .. '/.hammerspoon/', function(files)
    -- If any .lua or .html file changes, reload the configuration
    local doReload = false
    for _, file in pairs(files) do
      if file:sub(-4) == ".lua" or file:sub(-5) == ".html" then
        doReload = true
      end
    end
    if doReload then
      hs.reload();
      hs.notify.new({title="Hammerspoon", informativeText="Configuration reloaded", autoWithdraw=true, withdrawAfter=1}):send();
    end
  end):start()

  -- Update the menubaritem to indicate that the watcher is running
  if menubar ~= nil then
    menubar:setTooltip("Click to stop watching the Hammerspoon directory")
    menubar:setIcon(hs.image.imageFromName(menubarRefreshIcon))
  end
end

--- ReloadConfiguration:stop()
--- Method
--- Stop watching the Hammerspoon directory to live reload the configuration
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
function obj:stop()
  -- If the watcher is running, stop it
  if _watcher ~= nil then
    _watcher:stop()
    _watcher = nil
    -- Update the menubaritem to indicate that the watcher has stopped
    if menubar ~= nil then
      menubar:setTooltip("Click to start watching the Hammerspoon directory")
      menubar:setIcon(hs.image.imageFromName(menubarStopIcon))
    end
  end
end

--- ReloadConfiguration:toggle()
--- Method
--- Toggle watching the Hammerspoon directory to live reload the configuration
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
function obj:toggle()
  -- If the watcher is running, stop it. Otherwise, start it
  if _watcher == nil then
    self:start()
  else
    self:stop()
  end
end

--- ReloadConfiguration:init()
--- Method
--- Initialize the Spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This method is called when the Spoon is loaded
---  * It sets up the menubar item
function obj:init()
  -- Set the menubar title to indicate that the watcher is stopped
  menubar = hs.menubar.new()

  -- Set the click callback
  if menubar then
    menubar:setClickCallback(menubarClicked)
    menubar:setTooltip("Click to start watching the Hammerspoon directory")
    menubar:setIcon(hs.image.imageFromName(menubarStopIcon))
  end
end

function obj:toggleMenuItem()
  if menubar and menubar:isInMenuBar() then
    menubar:removeFromMenuBar()
  end

  if menubar and ~menubar:isInMenuBar() then
    menubar:returnToMenuBar()
  end
end

return obj
