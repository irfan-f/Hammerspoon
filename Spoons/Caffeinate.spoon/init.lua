--- === Caffeinate ===
---
--- Allow a user to force the display to stay awake or not, default menubar with option to hotkey
---
--- Based on / credits: Official Spoons Caffeine page —
--- https://www.hammerspoon.org/Spoons/Caffeine.html — and Hammerspoon `hs.caffeinate` usage.
---
--- Download:
local hkcap = require("hotkey_capture")
local menubar_sync = require("menubar_sync")

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Caffeinate"
obj.version = "0.1.0"
obj.author = "<irfan-f@gmail.com>"
obj.homepage = "https://www.hammerspoon.org/Spoons/Caffeine.html"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("Caffeinate")

local displayEffects = require("display_effects")

local settingsKeyHotkey = "Caffeinate.hotkey"

local panelWebview = nil
local panelInjector = nil

local windowStyle = hs.webview.windowMasks.borderless
  | hs.webview.windowMasks.titled
  | hs.webview.windowMasks.resizable
  | hs.webview.windowMasks.closable

obj.hotkey = { mods = { "cmd", "option" }, key = "C" }
obj._hotkey = nil

function obj:_loadHotkeyFromSettings()
  local hk = hs.settings.get(settingsKeyHotkey)
  if type(hk) == "table" and type(hk.mods) == "table" and type(hk.key) == "string" then
    self.hotkey = { mods = hk.mods, key = hk.key }
  end
end

function obj:init()
  self:_loadHotkeyFromSettings()
  return self
end

function obj:_settingsPanelStateTable()
  return {
    hotkey = hkcap.formatHotkey(self.hotkey),
  }
end

function obj:_buildSettingsPanelHtml()
  local path = hs.spoons.scriptPath() .. "/settings_panel.html"
  local file = io.open(path, "r")
  local html
  if file then
    html = file:read("a")
    file:close()
  else
    html = "<html><body>Missing settings_panel.html</body></html>"
  end
  local json = hs.json.encode(self:_settingsPanelStateTable())
  html = string.gsub(html, "</head>", "<script>window.__CAF_SETTINGS_STATE__=" .. json .. ";</script></head>", 1)
  return html
end

function obj:_syncSettingsPanelToWebview()
  if not panelWebview then
    return
  end
  local json = hs.json.encode(self:_settingsPanelStateTable())
  local js = "(function(){try{var s=" .. json .. ";window.__CAF_SETTINGS_STATE__=s;if(typeof boot==='function')boot(s);}catch(e){}})()"
  pcall(function()
    panelWebview:evaluateJavaScript(js)
  end)
end

function obj:_setHotkey(mods, key)
  self.hotkey = { mods = mods, key = key }
  if displayEffects.getPersistEnabled() then
    hs.settings.set(settingsKeyHotkey, self.hotkey)
  end
  self:bindHotkeys()
  if spoon and spoon.MenubarManager and type(spoon.MenubarManager.setMenuEntryHotkey) == "function" then
    spoon.MenubarManager:setMenuEntryHotkey("caffeinateDisplayIdle", hkcap.formatMenubarHotkey(self.hotkey))
  end
end

function obj:bindHotkeys()
  if self._hotkey then
    self._hotkey:delete()
    self._hotkey = nil
  end
  self._hotkey = hs.hotkey.bind(self.hotkey.mods, self.hotkey.key, function()
    self:toggle()
  end)
  self.logger.i("Caffeinate hotkey: " .. hkcap.formatHotkey(self.hotkey))
  return self
end

--- Webview to view and change the toggle hotkey.
function obj:showSettings()
  if panelWebview == nil then
    panelInjector = hs.webview.usercontent.new("caffeinateSettings")
    panelInjector:setCallback(function(message)
      if type(message) ~= "table" or type(message.body) ~= "table" then
        return
      end
      local t = message.body.type
      if t == "armHotkeyCapture" then
        hkcap.startCapture(obj, {
          notifyTitle = "Caffeinate",
          webview = panelWebview,
          onSuccess = function(s, mods, k)
            s:_setHotkey(mods, k)
          end,
          onRefresh = function()
            obj:_syncSettingsPanelToWebview()
          end,
        })
      end
    end)

    local mousePos = hs.mouse.absolutePosition()
    local w, h = 420, 200
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
        obj:_syncSettingsPanelToWebview()
      end
    end)
    panelWebview:html(self:_buildSettingsPanelHtml())
  end
  self:_syncSettingsPanelToWebview()
  panelWebview:show()
  panelWebview:bringToFront(true)
end

function obj:isEnabled()
  return hs.caffeinate.get("displayIdle") == true
end

function obj:setEnabled(enabled)
  hs.caffeinate.set("displayIdle", enabled and true or false)
  menubar_sync.refreshMenubarIfNeeded()
end

function obj:toggle()
  self:setEnabled(not self:isEnabled())
end

return obj
