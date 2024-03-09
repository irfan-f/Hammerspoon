--- === ReloadConfiguration ===
---
--- Provides an easy way to start and stop watching the Hammerspoon directory to live reload the configuration.
---
local obj = {}
obj.__index = obj

local _watcher = nil

-- Metadata
obj.name = "ReloadConfiguration"
obj.version = "0.1.0"
obj.author = "Irfan F."
obj.license = "MIT - https://opensource.org/licenses/MIT"

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
  if _watcher ~= nil then
    self:stop()
  end
  _watcher = hs.pathwatcher.new(os.getenv('HOME') .. '/.hammerspoon/', function(files)
    local doReload = false
    for _, file in pairs(files) do
      if file:sub(-4) == ".lua" then
        doReload = true
      end
    end
    if doReload then
      hs.reload()
    end
  end):start()
  hs.alert.show("Watching for live configuration reload")
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
  if _watcher ~= nil then
    _watcher:stop()
    hs.alert.show("Stopped watching for live configuration reload")
    _watcher = nil
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
  if _watcher == nil then
    self:start()
  else
    self:stop()
  end
end

return obj
