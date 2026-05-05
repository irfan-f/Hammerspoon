--- === BrightnessPlus ===
---
--- Gamma-based perceived brightness beyond macOS limits (all screens).
---
local hkcap = require("hotkey_capture")
local menubar_sync = require("menubar_sync")

local obj = {}
obj.__index = obj

obj.name = "BrightnessPlus"
obj.version = "0.1.0"
obj.author = "Irfan F."
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("BrightnessPlus")
local displayEffects = require("display_effects")

local panelWebview = nil
local panelInjector = nil

local settingsEnabledKey = "BrightnessPlus.enabled"
local settingsBoostKey = "BrightnessPlus.boost"
local settingsKeyHotkey = "BrightnessPlus.hotkey"
local settingsKeyMenubar = "BrightnessPlus.showMenubarExtra"

local windowStyle = hs.webview.windowMasks.borderless
  | hs.webview.windowMasks.titled
  | hs.webview.windowMasks.resizable
  | hs.webview.windowMasks.closable

obj.defaultBoost = 100
obj.hotkey = { mods = { "cmd", "option" }, key = "B" }
obj.showMenubarExtra = false
obj.menubarShortTitle = "B+"
obj._hotkey = nil
obj._extraMenubar = nil

local enabled = false
local boost = nil

local function clamp(n, minValue, maxValue)
  if n < minValue then
    return minValue
  end
  if n > maxValue then
    return maxValue
  end
  return n
end

local function lerp(a, b, t)
  return a + ((b - a) * t)
end

local function loadEnabled()
  if not displayEffects.getPersistEnabled() then
    return false
  end
  local v = hs.settings.get(settingsEnabledKey)
  if type(v) ~= "boolean" then
    return false
  end
  return v
end

local function saveEnabled(v)
  if not displayEffects.getPersistEnabled() then
    return
  end
  hs.settings.set(settingsEnabledKey, v and true or false)
end

local function loadBoost(defaultBoost)
  if not displayEffects.getPersistEnabled() then
    return defaultBoost
  end
  local v = hs.settings.get(settingsBoostKey)
  if type(v) ~= "number" then
    return defaultBoost
  end
  return clamp(v, 0, 100)
end

local function saveBoost(v)
  if not displayEffects.getPersistEnabled() then
    return
  end
  hs.settings.set(settingsBoostKey, v)
end

function obj:_loadPanelSettings()
  local hk = hs.settings.get(settingsKeyHotkey)
  if type(hk) == "table" and type(hk.mods) == "table" and type(hk.key) == "string" then
    self.hotkey = { mods = hk.mods, key = hk.key }
  end
  local mb = hs.settings.get(settingsKeyMenubar)
  if type(mb) == "boolean" then
    self.showMenubarExtra = mb
  end
end

function obj:_setHotkey(mods, key)
  self.hotkey = { mods = mods, key = key }
  if displayEffects.getPersistEnabled() then
    hs.settings.set(settingsKeyHotkey, self.hotkey)
  end
  self:bindHotkeys()
end

function obj:bindHotkeys()
  if self._hotkey then
    self._hotkey:delete()
    self._hotkey = nil
  end
  self._hotkey = hs.hotkey.bind(self.hotkey.mods, self.hotkey.key, function()
    self:toggle()
  end)
  self.logger.i("BrightnessPlus hotkey: " .. hkcap.formatHotkey(self.hotkey))
  return self
end

function obj:setShowMenubarExtra(flag)
  self.showMenubarExtra = flag and true or false
  if displayEffects.getPersistEnabled() then
    hs.settings.set(settingsKeyMenubar, self.showMenubarExtra)
  end
  self:refreshExtraMenubar()
  return self
end

function obj:refreshExtraMenubar()
  if self._extraMenubar then
    self._extraMenubar:delete()
    self._extraMenubar = nil
  end
  if not self.showMenubarExtra then
    return self
  end
  self._extraMenubar = hs.menubar.new()
  if not self._extraMenubar then
    return self
  end
  self._extraMenubar:setTitle(self.menubarShortTitle)
  self._extraMenubar:setTooltip("Brightness boost")
  self._extraMenubar:setMenu({
    {
      title = "Toggle brightness boost",
      fn = function()
        self:toggle()
      end,
    },
    {
      title = "Settings",
      fn = function()
        self:showOptions()
      end,
    },
  })
  return self
end

function obj:_stopHotkeyCapture()
  hkcap.stopCapture(self)
end

function obj:_panelStateTable()
  return {
    title = "Brightness boost",
    boost = self:getBoost(),
    hotkey = hkcap.formatHotkey(self.hotkey),
    showMenubarExtra = self.showMenubarExtra and true or false,
  }
end

function obj:_buildPanelHtml()
  local path = hs.spoons.scriptPath() .. "/panel.html"
  local file = io.open(path, "r")
  local html
  if file then
    html = file:read("a")
    file:close()
  else
    html = "<html><body>Missing panel.html</body></html>"
  end
  local json = hs.json.encode(self:_panelStateTable())
  html = string.gsub(html, "</head>", "<script>window.__BP_STATE__=" .. json .. ";</script></head>", 1)
  return html
end

function obj:_syncPanelToWebview()
  if not panelWebview then
    return
  end
  local json = hs.json.encode(self:_panelStateTable())
  local js = "(function(){try{var s=" .. json .. ";window.__BP_STATE__=s;if(typeof boot==='function')boot(s);}catch(e){}})()"
  pcall(function()
    panelWebview:evaluateJavaScript(js)
  end)
end

local function boostToGamma(boostValue)
  local v = clamp(boostValue, 0, 100)
  if v <= 0 then
    return { red = 1.0, green = 1.0, blue = 1.0 }, 0.0
  end

  local t = v / 100
  local mult = lerp(1.0, 1.6, t)
  return { red = mult, green = mult, blue = mult }, 0.0
end

function obj:apply()
  if boost == nil then
    boost = loadBoost(self.defaultBoost)
  end
  displayEffects.setCompute(function()
    local gamma, alpha = boostToGamma(boost)
    return gamma, alpha
  end)
  displayEffects.enable()
end

function obj:disable()
  if displayEffects.isEnabled() then
    displayEffects.disable()
  else
    hs.screen.restoreGamma()
  end
end

function obj:isEnabled()
  return enabled
end

function obj:setEnabled(v)
  enabled = v and true or false
  saveEnabled(enabled)

  if enabled then
    if
      spoon
      and spoon.LightFilter
      and spoon.LightFilter.isEnabled
      and spoon.LightFilter:isEnabled()
    then
      spoon.LightFilter:setEnabled(false)
    end
    self:apply()
    self.logger.i("Enabled brightness boost (boost=" .. tostring(self:getBoost()) .. ")")
    menubar_sync.refreshMenubarIfNeeded()
    return
  end

  self:disable()
  self.logger.i("Disabled brightness override")
  menubar_sync.refreshMenubarIfNeeded()
end

function obj:toggle()
  self:setEnabled(not self:isEnabled())
end

function obj:getBoost()
  if boost == nil then
    boost = loadBoost(self.defaultBoost)
  end
  return boost
end

function obj:setBoost(v)
  local n = tonumber(v)
  if not n then
    return
  end
  n = clamp(n, 0, 100)

  if n <= 0 then
    self:setEnabled(false)
    boost = 0
    saveBoost(0)
    return
  end

  boost = n
  saveBoost(boost)
  if enabled then
    displayEffects.apply()
    menubar_sync.refreshMenubarIfNeeded()
  else
    self:setEnabled(true)
  end
end

function obj:showOptions()
  if panelWebview == nil then
    panelInjector = hs.webview.usercontent.new("brightnessPlus")
    panelInjector:setCallback(function(message)
      if type(message) ~= "table" or type(message.body) ~= "table" then
        return
      end
      local t = message.body.type
      if t == "setBoost" then
        self:setBoost(message.body.value)
        self:_syncPanelToWebview()
        return
      end
      if t == "armHotkeyCapture" then
        hkcap.startCapture(self, {
          notifyTitle = "Brightness boost",
          webview = panelWebview,
          onSuccess = function(s, mods, key)
            s:_setHotkey(mods, key)
          end,
          onRefresh = function()
            self:_syncPanelToWebview()
          end,
        })
        return
      end
      if t == "setShowMenubarExtra" and message.body.value ~= nil then
        self:setShowMenubarExtra(message.body.value and true or false)
        self:_syncPanelToWebview()
        return
      end
    end)

    local mousePos = hs.mouse.absolutePosition()
    local w, h = 480, 300
    panelWebview = hs.webview.new(hs.geometry.rect(mousePos.x - w / 2, mousePos.y - 70, w, h), {
      javaScriptEnabled = true,
      javaScriptCanOpenWindowsAutomatically = false,
      developerExtrasEnabled = true,
    }, panelInjector)
    panelWebview:windowStyle(windowStyle)
    panelWebview:allowTextEntry(true)
    panelWebview:allowGestures(false)
    panelWebview:navigationCallback(function(action, wv, _nid, _err)
      if action == "didFinishNavigation" and wv == panelWebview then
        self:_syncPanelToWebview()
      end
    end)
    panelWebview:html(self:_buildPanelHtml())
  end
  self:_syncPanelToWebview()
  panelWebview:show()
  panelWebview:bringToFront(true)
end

function obj:init()
  self:_loadPanelSettings()
  enabled = loadEnabled()
  boost = loadBoost(self.defaultBoost)
  if enabled then
    self:apply()
  end
  return self
end

return obj
