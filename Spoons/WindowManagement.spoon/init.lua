--- === WindowManagement ===
---
--- Provide functions to move windows between displays and change window placement and sizing.
---
local hkcap = require("hotkey_capture")

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "WindowManagement"
obj.version = "0.1.0"
obj.author = "Irfan F."
obj.license = "MIT - https://opensource.org/licenses/MIT"

local settingsKeyOverrides = "WindowManagement.hotkeyOverrides"

local panelWebview = nil
local panelInjector = nil

local windowStyle = hs.webview.windowMasks.borderless
  | hs.webview.windowMasks.titled
  | hs.webview.windowMasks.resizable
  | hs.webview.windowMasks.closable

obj._hotkeyHandles = {}
obj._hotkeysBound = false

local function normalizeModsForBind(mods)
  if type(mods) ~= "table" then
    return {}
  end
  local out = {}
  for _, m in ipairs(mods) do
    if m == "option" then
      table.insert(out, "alt")
    else
      table.insert(out, m)
    end
  end
  return out
end

function obj:_loadOverrides()
  local t = hs.settings.get(settingsKeyOverrides)
  if type(t) ~= "table" then
    return {}
  end
  return t
end

function obj:_saveOverrides(overrides)
  hs.settings.set(settingsKeyOverrides, overrides)
end

--- WindowManagement:setup(gridSize, marginH, marginW)
--- Method
--- Establishes the specified grid size and margins
---
--- Parameters:
---  * gridSize - A `number` value specifying the grid size
---  * marginH - A `number` value specifying the horizontal margin
---  * marginW - A `number` value specifying the vertical margin
---
--- Returns:
---  * None
---
--- Notes:
---  * None
function obj:setup(gridSize, marginH, marginW)
  self.GRID_SIZE = gridSize
  self.HALF_GRID_SIZE = gridSize / 2

  hs.grid.setGrid(self.GRID_SIZE .. "x" .. self.GRID_SIZE)
  hs.grid.setMargins({ marginW, marginH }) -- hs.geometry object with the horizontal and vertical margins

  self.screenPositions = {
    -- Halves
    upper = { x = 0, y = 0, w = self.GRID_SIZE, h = self.HALF_GRID_SIZE }, -- upper half
    lower = { x = 0, y = self.HALF_GRID_SIZE, w = self.GRID_SIZE, h = self.HALF_GRID_SIZE }, -- lower half
    left = { x = 0, y = 0, w = self.HALF_GRID_SIZE, h = self.GRID_SIZE }, --- left half
    right = { x = self.HALF_GRID_SIZE, y = 0, w = self.HALF_GRID_SIZE, h = self.GRID_SIZE }, -- right half
    -- Quarters
    upperLeft = { x = 0, y = 0, w = self.HALF_GRID_SIZE, h = self.HALF_GRID_SIZE }, -- upper left
    upperRight = {
      x = self.HALF_GRID_SIZE,
      y = 0,
      w = self.HALF_GRID_SIZE,
      h = self.HALF_GRID_SIZE,
    }, -- upper right
    lowerLeft = { x = 0, y = self.HALF_GRID_SIZE, w = self.HALF_GRID_SIZE, h = self.HALF_GRID_SIZE }, -- lower left
    lowerRight = {
      x = self.HALF_GRID_SIZE,
      y = self.HALF_GRID_SIZE,
      w = self.HALF_GRID_SIZE,
      h = self.HALF_GRID_SIZE,
    }, --- lower right
  }
end

--- WindowManagement:maximizeWindow()
--- Method
--- Maximize the focused window
---
--- Parameters:
---  * None
---
--- Returns:
---  * A `WindowManagement` object
---
--- Notes:
---  * There may be updates to add to this method to allow for the window to be maximized to a specific screen
function obj:maximizeWindow()
  local window = hs.window.focusedWindow()
  if window == nil then
    return
  end
  window:maximize()
  return self
end

--- WindowManagement:moveWindowToPosition(cell)
--- Method
--- Move the focused window to the specified screen position
---
--- Parameters:
--- * cell - A `geometry` object specifying the screen position and size
---
--- Returns:
---  * A `WindowManagement` object
---
--- Notes:
---  * There may be updates to add to this method to allow for dynamic screen position creation
---  * The `cell` parameter can be user defined, or utilize one of the provided screen positions
function obj:moveWindowToPosition(cell)
  hs.printf("moving window")
  local window = hs.window.focusedWindow()
  if window == nil then
    return
  end
  local screen = window:screen()
  hs.grid.set(window, cell, screen)
  return self
end

--- WindowManagement:moveWindowToDisplay(d)
--- Method
--- Move the focused window to the specified display
---
--- Parameters:
---  * d - A `number` value specifying the display number
---
--- Returns:
---  * A `WindowManagement` object
---
--- Notes:
---  * There may be updates to add to this method to allow for dynamic display selection
function obj:moveWindowToDisplay(d)
  local displays = hs.screen.allScreens()
  local win = hs.window.focusedWindow()
  if win == nil then
    hs.printf("No focused window")
    return
  end
  if displays == nil then
    hs.printf("No displays found")
    return
  end
  if d > #displays then
    hs.printf("Display " .. d .. " not found")
    return
  end
  win:moveToScreen(displays[d], false, true)
  return self
end

--- Default hotkey specs (single source for bind + help UI).
--- Each: id, mods, key, menuTitle (hs.hotkey message), description (human-readable).
local function defaultHotkeySpecs(self)
  return {
    {
      id = "maximize",
      mods = { "shift", "cmd" },
      key = "return",
      menuTitle = "Window - Maximize",
      description = "Maximize the focused window",
      fn = function()
        self:maximizeWindow()
      end,
    },
    {
      id = "halfLeft",
      mods = { "alt", "cmd" },
      key = "left",
      menuTitle = "Window - Left",
      description = "Move window to left half of the screen",
      fn = function()
        self:moveWindowToPosition(self.screenPositions.left)
      end,
    },
    {
      id = "halfTop",
      mods = { "alt", "cmd" },
      key = "up",
      menuTitle = "Window - Top",
      description = "Move window to top half of the screen",
      fn = function()
        self:moveWindowToPosition(self.screenPositions.upper)
      end,
    },
    {
      id = "halfBottom",
      mods = { "alt", "cmd" },
      key = "down",
      menuTitle = "Window - Bottom",
      description = "Move window to bottom half of the screen",
      fn = function()
        self:moveWindowToPosition(self.screenPositions.lower)
      end,
    },
    {
      id = "halfRight",
      mods = { "alt", "cmd" },
      key = "right",
      menuTitle = "Window - Right",
      description = "Move window to right half of the screen",
      fn = function()
        self:moveWindowToPosition(self.screenPositions.right)
      end,
    },
    {
      id = "quarterUpperLeft",
      mods = { "shift", "cmd" },
      key = "left",
      menuTitle = "Window - Top Left",
      description = "Move window to upper-left quarter",
      fn = function()
        self:moveWindowToPosition(self.screenPositions.upperLeft)
      end,
    },
    {
      id = "quarterUpperRight",
      mods = { "shift", "cmd" },
      key = "up",
      menuTitle = "Window - Top Right",
      description = "Move window to upper-right quarter",
      fn = function()
        self:moveWindowToPosition(self.screenPositions.upperRight)
      end,
    },
    {
      id = "quarterLowerLeft",
      mods = { "shift", "cmd" },
      key = "down",
      menuTitle = "Window - Bottom Left",
      description = "Move window to lower-left quarter",
      fn = function()
        self:moveWindowToPosition(self.screenPositions.lowerLeft)
      end,
    },
    {
      id = "quarterLowerRight",
      mods = { "shift", "cmd" },
      key = "right",
      menuTitle = "Window - Bottom Right",
      description = "Move window to lower-right quarter",
      fn = function()
        self:moveWindowToPosition(self.screenPositions.lowerRight)
      end,
    },
    {
      id = "display1",
      mods = { "shift", "cmd" },
      key = "1",
      menuTitle = "Window - Display 1",
      description = "Move window to display 1",
      fn = function()
        self:moveWindowToDisplay(1)
      end,
    },
    {
      id = "display2",
      mods = { "shift", "cmd" },
      key = "2",
      menuTitle = "Window - Display 2",
      description = "Move window to display 2",
      fn = function()
        self:moveWindowToDisplay(2)
      end,
    },
    {
      id = "display3",
      mods = { "shift", "cmd" },
      key = "3",
      menuTitle = "Window - Display 3",
      description = "Move window to display 3",
      fn = function()
        self:moveWindowToDisplay(3)
      end,
    },
  }
end

function obj:_mergedSpecs()
  local overrides = self:_loadOverrides()
  local merged = {}
  for _, spec in ipairs(defaultHotkeySpecs(self)) do
    local mods = spec.mods
    local key = spec.key
    local o = overrides[spec.id]
    if type(o) == "table" and type(o.mods) == "table" and type(o.key) == "string" then
      mods = normalizeModsForBind(o.mods)
      key = o.key
    end
    table.insert(merged, {
      id = spec.id,
      mods = mods,
      key = key,
      menuTitle = spec.menuTitle,
      description = spec.description,
      fn = spec.fn,
    })
  end
  return merged
end

--- WindowManagement:getDefaultHotkeyReference()
--- Method
--- Ordered list of bindings for help UI: id, mods, key, description (includes saved overrides).
function obj:getDefaultHotkeyReference()
  local out = {}
  for _, spec in ipairs(self:_mergedSpecs()) do
    table.insert(out, {
      id = spec.id,
      mods = spec.mods,
      key = spec.key,
      description = spec.description,
    })
  end
  return out
end

function obj:_hotkeysPanelStateTable()
  local actions = {}
  for _, row in ipairs(self:getDefaultHotkeyReference()) do
    table.insert(actions, {
      id = row.id,
      description = row.description,
      hotkey = hkcap.formatHotkey({ mods = row.mods, key = row.key }),
    })
  end
  return { actions = actions }
end

function obj:_buildHotkeysPanelHtml()
  local path = hs.spoons.scriptPath() .. "/hotkeys_panel.html"
  local file = io.open(path, "r")
  local html
  if file then
    html = file:read("a")
    file:close()
  else
    html = "<html><body>Missing hotkeys_panel.html</body></html>"
  end
  local json = hs.json.encode(self:_hotkeysPanelStateTable())
  html = string.gsub(html, "</head>", "<script>window.__WM_HOTKEYS_STATE__=" .. json .. ";</script></head>", 1)
  return html
end

function obj:_syncHotkeysPanelToWebview()
  if not panelWebview then
    return
  end
  local json = hs.json.encode(self:_hotkeysPanelStateTable())
  local js = "(function(){try{var s=" .. json .. ";window.__WM_HOTKEYS_STATE__=s;if(typeof boot==='function')boot(s);}catch(e){}})()"
  pcall(function()
    panelWebview:evaluateJavaScript(js)
  end)
end

function obj:_setHotkeyOverrideForId(id, mods, key)
  if type(id) ~= "string" or id == "" then
    return
  end
  local overrides = self:_loadOverrides()
  overrides[id] = { mods = normalizeModsForBind(mods), key = key }
  self:_saveOverrides(overrides)
  if self._hotkeysBound then
    self:bindDefaultHotkeys()
  end
  self:_syncHotkeysPanelToWebview()
end

--- WindowManagement:showHotkeysPanel()
--- Method
--- Webview listing each window action and its hotkey; Set… records a new binding (persisted).
function obj:showHotkeysPanel()
  if panelWebview == nil then
    panelInjector = hs.webview.usercontent.new("windowManagementHotkeys")
    panelInjector:setCallback(function(message)
      if type(message) ~= "table" or type(message.body) ~= "table" then
        return
      end
      local t = message.body.type
      if t == "armHotkeyCapture" then
        local id = message.body.id
        if type(id) ~= "string" then
          return
        end
        hkcap.startCapture(obj, {
          notifyTitle = "Window shortcuts",
          webview = panelWebview,
          onSuccess = function(s, mods, k)
            s:_setHotkeyOverrideForId(id, mods, k)
          end,
          onRefresh = function()
            obj:_syncHotkeysPanelToWebview()
          end,
        })
      end
    end)

    local mousePos = hs.mouse.absolutePosition()
    local w, h = 540, 440
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
        obj:_syncHotkeysPanelToWebview()
      end
    end)
    panelWebview:html(self:_buildHotkeysPanelHtml())
  end
  self:_syncHotkeysPanelToWebview()
  panelWebview:show()
  panelWebview:bringToFront(true)
end

--- WindowManagement:bindDefaultHotkeys()
--- Method
--- Bind the default hotkeys (or saved overrides). Safe to call again to refresh bindings.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * These work best with a grid size of 2
---  * Default hotkeys are:
---   * Maximize - `shift` + `cmd` + `return`
---   * Move to half positions - `alt` + `cmd` + ['left`, `up`, `down`, `right`],
---   * Move to quarter positions - `shift` + `cmd` + [`left`, `up`, `down`, `right`]
---   * Move to display - `shift` + `cmd` + [`1`, `2`, `3`]
function obj:bindDefaultHotkeys()
  for _, h in ipairs(self._hotkeyHandles) do
    if h then
      h:delete()
    end
  end
  self._hotkeyHandles = {}
  for _, spec in ipairs(self:_mergedSpecs()) do
    local hk = hs.hotkey.bind(spec.mods, spec.key, spec.menuTitle, spec.fn)
    table.insert(self._hotkeyHandles, hk)
  end
  self._hotkeysBound = true
end

return obj
