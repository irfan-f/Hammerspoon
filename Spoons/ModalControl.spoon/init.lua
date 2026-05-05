--- === ModalControl ===
---
--- A simple modal for display controls (warmth/brightness boost) and quick toggles.
---
local obj = {}
obj.__index = obj

obj.name = "ModalControl"
obj.version = "0.1.0"
obj.author = "Irfan F."
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("ModalControl")

obj.mods = { "cmd", "alt", "ctrl" }
obj.key = "b"
obj.stepWarmth = 5
obj.stepBrightness = 10

local modal = nil

local function safeSpoon(name)
  if spoon and spoon[name] then
    return spoon[name]
  end
  return nil
end

local function setWarmthDelta(delta)
  local lf = safeSpoon("LightFilter")
  if not lf then
    hs.alert.show("LightFilter not available")
    return
  end
  local w = lf:getWarmth()
  lf:setWarmth(w + delta)
  hs.alert.show("Warmth: " .. tostring(lf:getWarmth()) .. "%")
end

local function setBrightnessLevelDelta(delta)
  local bp = safeSpoon("BrightnessPlus")
  if not bp then
    hs.alert.show("BrightnessPlus not available")
    return
  end
  local v = bp:getLevel()
  bp:setLevel(v + delta)
  bp:setEnabled(true)
  hs.alert.show("Brightness: " .. tostring(bp:getLevel()) .. "%")
end

function obj:start()
  if modal then
    return
  end

  local stepWarmth = self.stepWarmth
  local stepBrightness = self.stepBrightness

  modal = hs.hotkey.modal.new(self.mods, self.key, "Display controls")

  function modal.entered()
    hs.alert.show("Display controls: [ / ] warmth, - / = brightness, esc to exit")
  end

  function modal.exited()
    hs.alert.closeAll()
  end

  modal:bind({}, "escape", function()
    modal:exit()
  end)
  modal:bind({}, "q", function()
    modal:exit()
  end)

  -- Warmth controls
  modal:bind({}, "[", function()
    setWarmthDelta(-stepWarmth)
  end)
  modal:bind({}, "]", function()
    setWarmthDelta(stepWarmth)
  end)

  -- Brightness controls
  modal:bind({}, "-", function()
    setBrightnessLevelDelta(-stepBrightness)
  end)
  modal:bind({}, "=", function()
    setBrightnessLevelDelta(stepBrightness)
  end)

  -- Toggles
  modal:bind({}, "f", function()
    local lf = safeSpoon("LightFilter")
    if lf then
      lf:toggle()
    end
  end)
  modal:bind({}, "p", function()
    local bp = safeSpoon("BrightnessPlus")
    if bp then
      bp:toggle()
    end
  end)
end

return obj
