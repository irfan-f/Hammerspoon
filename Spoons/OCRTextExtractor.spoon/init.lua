--- === OCRTextExtractor ===
---
--- Capture a screen region, OCR it, and copy the text to clipboard.
---
local hkcap = require("hotkey_capture")

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "OCRTextExtractor"
obj.version = "0.1.0"
obj.author = "Irfan F."
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("OCRTextExtractor")

-- Config
obj.hotkey = { mods = { "cmd", "option", "shift" }, key = "O" }
obj.showMenubarItem = false
obj.menubarTitle = "OCR"
obj.notificationTitle = "OCR"
obj.outputAction = "prompt" -- prompt | clipboard | textedit | folder (legacy "editor" → textedit)
obj.inputAction = "prompt" -- prompt | screenshot | image | clipboard
obj.outputFolder = nil
obj._settingsPrefix = "OCRTextExtractor."

-- State
obj._menubar = nil
obj._captureTask = nil
obj._ocrTask = nil

-- UI (LightFilter-style hs.webview panel)
obj._uiWebview = nil
obj._uiInjector = nil
obj._uiMode = "output" -- output | settings
obj._hotkeyCaptureTap = nil
obj._hotkeyCaptureTimer = nil
-- (no per-result UI state kept in this spoon)

local function notify(title, text)
  hs.notify.new({ title = title, informativeText = text }):send()
end

local function joinArgs(args)
  if not args or #args == 0 then return "" end
  local out = {}
  for _, a in ipairs(args) do
    table.insert(out, tostring(a))
  end
  return table.concat(out, " ")
end

local function tmpPath(filename)
  local dir = hs.fs.temporaryDirectory()
  if dir:sub(-1) ~= "/" then
    dir = dir .. "/"
  end
  return dir .. filename
end

local function fileExists(path)
  return hs.fs.attributes(path) ~= nil
end

local function isExecutable(path)
  if type(path) ~= "string" or path == "" then return false end
  if not fileExists(path) then return false end
  local ok = select(2, hs.execute(string.format("/bin/sh -lc %q", "[ -x " .. string.format("%q", path) .. " ]")))
  return ok == true
end

local function commandExists(cmd)
  local ok = select(2, hs.execute(string.format("/bin/sh -lc %q", "command -v " .. cmd .. " >/dev/null 2>&1")))
  return ok == true
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Known settings values (invalid persisted strings fall back safely).
local VALID_INPUT_ACTIONS = {
  prompt = true,
  screenshot = true,
  image = true,
  clipboard = true,
}
local VALID_OUTPUT_ACTIONS = {
  prompt = true,
  clipboard = true,
  textedit = true,
  folder = true,
}

local function normalizeInputAction(action, logger)
  if type(action) ~= "string" or action == "" then
    return "prompt"
  end
  if VALID_INPUT_ACTIONS[action] then
    return action
  end
  if logger then
    logger.w("Unknown inputAction in settings, using prompt: " .. tostring(action))
  end
  return "prompt"
end

local function normalizeOutputAction(action, logger)
  if type(action) ~= "string" or action == "" then
    return "prompt"
  end
  if action == "editor" then
    return "textedit"
  end
  if VALID_OUTPUT_ACTIONS[action] then
    return action
  end
  if logger then
    logger.w("Unknown outputAction in settings, using prompt: " .. tostring(action))
  end
  return "prompt"
end

local function isDirPath(path)
  if type(path) ~= "string" or path == "" then
    return false
  end
  local a = hs.fs.attributes(path)
  return a and a.mode == "directory"
end

--- Best-effort check that we can create a file in `path` (directory).
local function directoryAllowsCreate(path)
  if not isDirPath(path) then
    return false
  end
  local base = path
  if base:sub(-1) ~= "/" then
    base = base .. "/"
  end
  local probe = base .. ".hammerspoon_ocr_write_probe_" .. tostring(os.time())
  local f = io.open(probe, "w")
  if not f then
    return false
  end
  f:close()
  pcall(os.remove, probe)
  return true
end

local PNG_SIG = "\137PNG\r\n\26\n"

local function isNonEmptyReadableFile(path)
  local a = hs.fs.attributes(path)
  return fileExists(path) and a and (a.size or 0) > 8
end

local function isPlausibleScreenCaptureFile(path)
  if not fileExists(path) then
    return false
  end
  local attrs = hs.fs.attributes(path)
  if not attrs or (attrs.size or 0) < #PNG_SIG then
    return false
  end
  local f = io.open(path, "rb")
  if not f then
    return false
  end
  local head = f:read(#PNG_SIG)
  f:close()
  return head == PNG_SIG
end

local function tryRemoveTempOcrFile(path)
  if type(path) ~= "string" or path == "" then
    return
  end
  local tmp = hs.fs.temporaryDirectory()
  if tmp:sub(-1) ~= "/" then
    tmp = tmp .. "/"
  end
  if path:sub(1, #tmp) ~= tmp then
    return
  end
  pcall(os.remove, path)
end

local function userFacingOcrFailureMessage(exitCode, stderr)
  local s = trim(stderr or "")
  if s ~= "" then
    local line = s:match("[^\r\n]+") or s
    line = trim(line)
    if #line > 160 then
      line = line:sub(1, 157) .. "…"
    end
    return "OCR failed: " .. line
  end
  return "OCR failed (exit " .. tostring(exitCode) .. ")"
end

local function resolveCommandPath(cmd)
  if type(cmd) ~= "string" or cmd == "" then return nil end
  if cmd:sub(1, 1) == "/" then
    return cmd
  end
  local out, ok = hs.execute(string.format("/bin/sh -lc %q", "command -v " .. cmd .. " 2>/dev/null"))
  if ok ~= true then return nil end
  out = trim(out or "")
  if out == "" then return nil end
  return out
end

function obj:init()
  self:_loadSettings()
  return self
end

function obj:_settingsKey(name)
  return tostring(self._settingsPrefix) .. tostring(name)
end

function obj:_loadSettings()
  local input = hs.settings.get(self:_settingsKey("inputAction"))
  if type(input) == "string" and input ~= "" then
    self.inputAction = normalizeInputAction(input, self.logger)
  end
  local action = hs.settings.get(self:_settingsKey("outputAction"))
  if type(action) == "string" and action ~= "" then
    self.outputAction = normalizeOutputAction(action, self.logger)
  end
  local folder = hs.settings.get(self:_settingsKey("outputFolder"))
  if type(folder) == "string" and folder ~= "" then
    self.outputFolder = folder
  end
  local showMb = hs.settings.get(self:_settingsKey("showMenubarItem"))
  if type(showMb) == "boolean" then
    self.showMenubarItem = showMb
  end

  local hk = hs.settings.get(self:_settingsKey("hotkey"))
  if type(hk) == "table" and type(hk.mods) == "table" and type(hk.key) == "string" then
    self.hotkey = { mods = hk.mods, key = hk.key }
  end

  if self.outputAction == "editor" then
    self.outputAction = "textedit"
    self:_saveSetting("outputAction", "textedit")
  end

  self.inputAction = normalizeInputAction(self.inputAction, self.logger)
  self.outputAction = normalizeOutputAction(self.outputAction, self.logger)
end

function obj:_saveSetting(name, value)
  hs.settings.set(self:_settingsKey(name), value)
end

function obj:setOutputAction(action)
  if type(action) ~= "string" then
    return self
  end
  action = normalizeOutputAction(action, self.logger)
  self.outputAction = action
  self:_saveSetting("outputAction", action)
  return self
end

function obj:setInputAction(action)
  if type(action) ~= "string" then
    return self
  end
  self.inputAction = normalizeInputAction(action, self.logger)
  self:_saveSetting("inputAction", self.inputAction)
  return self
end

function obj:setOutputFolder(path)
  if type(path) ~= "string" or path == "" then return self end
  self.outputFolder = path
  self:_saveSetting("outputFolder", path)
  return self
end

function obj:setShowMenubarItem(flag)
  self.showMenubarItem = flag and true or false
  self:_saveSetting("showMenubarItem", self.showMenubarItem)
  self:refreshMenubarItem()
  return self
end

function obj:_setHotkey(mods, key)
  if type(mods) ~= "table" or type(key) ~= "string" or key == "" then
    return self
  end
  self.hotkey = { mods = mods, key = key }
  self:_saveSetting("hotkey", { mods = mods, key = key })

  if self._hotkey then
    self._hotkey:delete()
    self._hotkey = nil
  end
  self:bindHotkeys()
  return self
end

function obj:_stopHotkeyCapture()
  hkcap.stopCapture(self)
end

function obj:_startHotkeyCapture()
  hkcap.startCapture(self, {
    notifyTitle = self.notificationTitle,
    webview = self._uiWebview,
    onSuccess = function(s, mods, key)
      s:_setHotkey(mods, key)
    end,
    onRefresh = function(s)
      s:_refreshUi()
    end,
  })
end

local function writeTextFile(path, text)
  local f, err = io.open(path, "w")
  if not f then
    return false, err
  end
  f:write(text)
  f:close()
  return true
end

function obj:_openFileInTextEdit(path)
  local _out, ok = hs.execute(string.format("%q -a %q %q", "/usr/bin/open", "TextEdit", path))
  return ok == true
end

function obj:_saveToFolder(text)
  local folder = self.outputFolder
  if type(folder) ~= "string" or folder == "" then
    notify(self.notificationTitle, "No output folder set. Choose one in OCR settings.")
    self:openSettingsPanel()
    return
  end
  if not isDirPath(folder) then
    notify(self.notificationTitle, "Output folder is missing or not a folder:\n" .. folder)
    return
  end
  if not directoryAllowsCreate(folder) then
    notify(self.notificationTitle, "Cannot write to output folder (permission denied?):\n" .. folder)
    return
  end
  local filename = "ocr_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
  local path = folder
  if path:sub(-1) ~= "/" then
    path = path .. "/"
  end
  path = path .. filename
  local ok, err = writeTextFile(path, text)
  if not ok then
    notify(self.notificationTitle, "Failed to save: " .. tostring(err))
    return
  end
  local _out, execOk = hs.execute(string.format("%q %q", "/usr/bin/open", path))
  if execOk ~= true then
    self.logger.w("open saved OCR file may have failed: " .. tostring(path))
    notify(self.notificationTitle, "Saved (open in Finder failed): " .. filename)
    return
  end
  notify(self.notificationTitle, "Saved: " .. filename)
end

function obj:_writeTempText(text)
  local path = tmpPath("ocr_" .. tostring(hs.host.uuid() or "host") .. "_" .. tostring(os.time()) .. ".txt")
  local ok, err = writeTextFile(path, text)
  if not ok then
    notify(self.notificationTitle, "Failed to write temp file: " .. tostring(err))
    return nil
  end
  return path
end

function obj:_applyOutputAction(action, text)
  action = normalizeOutputAction(action, self.logger)
  if action == "editor" then
    action = "textedit"
  end

  if type(text) ~= "string" then
    text = ""
  end

  if action == "clipboard" then
    local okPb, pbResult = pcall(function()
      return hs.pasteboard.setContents(text)
    end)
    if not okPb then
      notify(self.notificationTitle, "Clipboard error: " .. tostring(pbResult))
      return
    end
    if pbResult == false then
      notify(self.notificationTitle, "Could not copy to clipboard (denied or unavailable)")
      return
    end
    notify(self.notificationTitle, "Copied to clipboard")
    return
  end

  if action == "textedit" then
    local path = self:_writeTempText(text)
    if not path then
      return
    end
    if not self:_openFileInTextEdit(path) then
      self.logger.w("TextEdit open command returned failure for " .. tostring(path))
      notify(self.notificationTitle, "Temp file saved; opening TextEdit may have failed")
      return
    end
    notify(self.notificationTitle, "Opened in TextEdit")
    return
  end

  if action == "folder" then
    self:_saveToFolder(text)
    return
  end

  -- default: prompt
  if text == "" then
    notify(self.notificationTitle, "Run OCR first (capture, image file, or clipboard image)")
    return
  end
  self:showOutputChooser(text)
end

local windowStyle = hs.webview.windowMasks.borderless
  | hs.webview.windowMasks.titled
  | hs.webview.windowMasks.resizable
  | hs.webview.windowMasks.closable

local function applescriptEscape(s)
  s = tostring(s or "")
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  return s
end

local function normalizeApplescriptValue(result)
  if result == nil then
    return nil
  end
  if type(result) == "string" then
    local s = trim(result):gsub("\r", ""):gsub("%z", "")
    return s ~= "" and s or nil
  end
  if type(result) == "table" then
    for _, v in ipairs(result) do
      if type(v) == "string" then
        local s = trim(v):gsub("\r", ""):gsub("%z", "")
        if s ~= "" then
          return s
        end
      end
    end
    return nil
  end
  local s = trim(tostring(result)):gsub("\r", ""):gsub("%z", "")
  if s == "" or s:match("^userdata:") then
    return nil
  end
  return s
end

local function runApplescript(script)
  local app = hs.application and (hs.application.get("Hammerspoon") or hs.application.frontmostApplication())
  if app and app.activate then
    -- Ensure dialogs appear on top (especially with non-activating webviews).
    app:activate(true)
  end

  -- Use Hammerspoon's osascript bridge to avoid shell quoting issues.
  if not hs.osascript or not hs.osascript.applescript then
    return nil
  end
  local ok, result = hs.osascript.applescript(script)
  if ok ~= true then
    obj.logger.w("AppleScript failed: " .. hs.inspect(result))
    return nil
  end
  return normalizeApplescriptValue(result)
end

local function pickFolderApplescript(prompt, defaultPath)
  local default = defaultPath or (os.getenv("HOME") .. "/Downloads")
  local script = string.format(
    [[
set defaultPosix to "%s"
try
  set defaultAlias to POSIX file defaultPosix as alias
on error
  set defaultAlias to (path to downloads folder)
end try
set f to choose folder with prompt "%s" default location defaultAlias
return (POSIX path of f) as text
]],
    applescriptEscape(default),
    applescriptEscape(prompt or "Choose folder")
  )
  local picked = runApplescript(script)
  if picked then
    return picked
  end
  notify("OCR", "Folder picker cancelled or failed")
  return nil
end

local function pickImageFileApplescript(prompt, defaultPath)
  local default = defaultPath or (os.getenv("HOME") .. "/Downloads")
  local script = string.format(
    [[
set defaultPosix to "%s"
try
  set defaultAlias to POSIX file defaultPosix as alias
on error
  set defaultAlias to (path to downloads folder)
end try
set f to choose file with prompt "%s" of type {"public.image"} default location defaultAlias
return (POSIX path of f) as text
]],
    applescriptEscape(default),
    applescriptEscape(prompt or "Choose image")
  )
  local picked = runApplescript(script)
  if picked then
    return picked
  end
  notify("OCR", "Image picker cancelled or failed")
  return nil
end

function obj:_uiHtmlPath()
  local spoonPath = hs.spoons.scriptPath()
  return spoonPath .. "/ocr_ui.html"
end

function obj:_uiStateTable()
  return {
    mode = "settings",
    title = "OCR settings",
    subtitle = "Default input (OCR…) and output after OCR",
    folder = self.outputFolder or "(not set)",
    defaultInput = self.inputAction or "prompt",
    defaultOutput = self.outputAction or "prompt",
    hotkey = hkcap.formatHotkey(self.hotkey),
    showMenubarItem = self.showMenubarItem and true or false,
  }
end

function obj:_buildUiHtml()
  local path = self:_uiHtmlPath()
  local file = io.open(path, "r")
  local html
  if file then
    html = file:read("a")
    file:close()
  else
    html = "<html><body style='font-family:-apple-system'>Missing ocr_ui.html</body></html>"
  end

  local json = hs.json.encode(self:_uiStateTable())
  html = string.gsub(html, "</head>", "<script>window.__OCR_STATE__=" .. json .. ";</script></head>", 1)
  return html
end

-- WKWebView often does not reliably re-run our boot path after :html() reloads; push state via JS instead.
function obj:_syncUiStateToWebview()
  if not self._uiWebview then
    return
  end
  local json = hs.json.encode(self:_uiStateTable())
  local js = "(function(){try{var s="
    .. json
    .. ";window.__OCR_STATE__=s;if(typeof boot==='function')boot(s);}catch(e){}})()"
  local ok, err = pcall(function()
    self._uiWebview:evaluateJavaScript(js)
  end)
  if not ok then
    self.logger.w("evaluateJavaScript failed: " .. tostring(err))
  end
end

function obj:_closeUi()
  self:_stopHotkeyCapture()
  if self._uiWebview then
    self._uiWebview:delete()
    self._uiWebview = nil
  end
  self._uiInjector = nil
end

function obj:_refreshUi()
  if not self._uiWebview then
    return
  end
  self:_syncUiStateToWebview()

  -- Keep the panel compact by default; user can resize manually.
  local w = 480
  local h = 280
  local f = self._uiWebview:frame()
  if f then
    self._uiWebview:frame({ x = f.x, y = f.y, w = w, h = h })
  end
end

function obj:_ensureUi()
  if self._uiWebview then
    return true
  end

  local injector = hs.webview.usercontent.new("ocr")
  self._uiInjector = injector
  injector:setCallback(function(message)
    if type(message) ~= "table" or type(message.body) ~= "table" then
      return
    end

    local t = message.body.type
    if t == "close" then
      self:_closeUi()
      return
    end

    if t == "armHotkeyCapture" then
      self:_startHotkeyCapture()
      return
    end

    if t == "setHotkey" and type(message.body.key) == "string" and type(message.body.mods) == "table" then
      -- Legacy path from older web UI; prefer eventtap capture.
      self:_setHotkey(message.body.mods, message.body.key)
      self:_refreshUi()
      return
    end

    if t == "setDefault" and type(message.body.action) == "string" then
      self:setOutputAction(message.body.action)
      notify(self.notificationTitle, "Default output: " .. tostring(message.body.action))
      self:_refreshUi()
      return
    end

    if t == "setDefaultInput" and type(message.body.action) == "string" then
      self:setInputAction(message.body.action)
      notify(self.notificationTitle, "Default input: " .. tostring(message.body.action))
      self:_refreshUi()
      return
    end

    if t == "pickFolder" then
      local path = pickFolderApplescript("Choose OCR output folder", self.outputFolder or (os.getenv("HOME") .. "/Downloads"))
      if type(path) == "string" then
        if not directoryAllowsCreate(path) then
          notify(self.notificationTitle, "That folder is not writable; choose another")
        else
          self:setOutputFolder(path)
          notify(self.notificationTitle, "Output folder set")
        end
      end
      self:_refreshUi()
      return
    end

    if t == "setShowMenubarItem" and message.body.value ~= nil then
      self:setShowMenubarItem(message.body.value and true or false)
      notify(self.notificationTitle, self.showMenubarItem and "OCR icon shown in menu bar" or "OCR menu bar icon hidden")
      self:_refreshUi()
      return
    end

    if t == "openFolder" then
      if type(self.outputFolder) == "string" and self.outputFolder ~= "" then
        hs.execute(string.format("%q %q", "/usr/bin/open", self.outputFolder))
      else
        notify(self.notificationTitle, "No output folder set")
      end
      return
    end

    if t == "reset" then
      self:_stopHotkeyCapture()
      self:setInputAction("prompt")
      self:setOutputAction("prompt")
      self.outputFolder = nil
      self:_saveSetting("outputFolder", nil)
      self:_saveSetting("hotkey", nil)
      self:setShowMenubarItem(false)
      notify(self.notificationTitle, "OCR settings reset")
      self:_refreshUi()
      return
    end

  end)

  local mousePos = hs.mouse.absolutePosition()
  local uiMode = self._uiMode or "output"
  local w = uiMode == "settings" and 480 or 460
  local h = uiMode == "settings" and 280 or 270
  local rect = hs.geometry.rect(mousePos.x - (w / 2), mousePos.y - 90, w, h)

  local webview = hs.webview.new(rect, {
    javaScriptEnabled = true,
    javaScriptCanOpenWindowsAutomatically = false,
    developerExtrasEnabled = true,
  }, injector)

  self._uiWebview = webview
  webview:windowStyle(windowStyle)
  webview:allowTextEntry(true)
  webview:allowGestures(false)
  webview:navigationCallback(function(action, wv, _navID, _err)
    if action == "didFinishNavigation" and wv == self._uiWebview then
      self:_syncUiStateToWebview()
    end
  end)
  webview:html(self:_buildUiHtml())

  return true
end

function obj:openSettingsPanel()
  self._uiMode = "settings"
  if not self:_ensureUi() then
    return
  end
  self:_refreshUi()
  self._uiWebview:show()
end

-- Back-compat names used by init.lua / older callsites
function obj:showOutputChooser(text)
  -- Prompt UI is a lightweight chooser; settings panel is separate.
  local chooser = hs.chooser.new(function(choice)
    if not choice then return end
    local action = choice.action
    if type(action) ~= "string" then return end
    if action == "settings" then
      self:openSettingsPanel()
      return
    end
    self:_applyOutputAction(action, text)
  end)

  chooser:choices({
    { id = "clipboard", text = "Copy to clipboard", action = "clipboard" },
    { id = "textedit", text = "Open in TextEdit", action = "textedit" },
    { id = "folder", text = "Save to folder", action = "folder" },
    { id = "settings", text = "OCR settings…", action = "settings" },
  })
  chooser:placeholderText("OCR output")
  chooser:show()
end

function obj:showSettingsChooser()
  self:openSettingsPanel()
end

function obj:showDefaultOutputChooser()
  -- Defaults are now handled via the dropdown in the web UI.
  self._uiMode = "settings"
  self:openSettingsPanel()
end

function obj:runDefaultInputFlow()
  local input = normalizeInputAction(self.inputAction, self.logger)
  if input == "screenshot" then
    self:captureAndCopy()
    return
  elseif input == "image" then
    self:ocrPickImageFile()
    return
  elseif input == "clipboard" then
    self:ocrClipboardImage()
    return
  end

  local c = hs.chooser.new(function(choice)
    if not choice then
      return
    end
    if choice.id == "screenshot" then
      self:captureAndCopy()
    elseif choice.id == "image" then
      self:ocrPickImageFile()
    elseif choice.id == "clipboard" then
      self:ocrClipboardImage()
    end
  end)

  c:choices({
    { id = "screenshot", text = "Screenshot…", subText = "Select a region on screen" },
    { id = "image", text = "Image file…", subText = "Pick an image from disk" },
    { id = "clipboard", text = "Clipboard image", subText = "OCR the image in clipboard" },
  })
  c:placeholderText("Start OCR")
  c:show()
end

function obj:refreshMenubarItem()
  if self._menubar then
    self._menubar:delete()
    self._menubar = nil
  end
  if not self.showMenubarItem then
    return self
  end
  self._menubar = hs.menubar.new()
  if not self._menubar then
    return self
  end
  self._menubar:setTitle(self.menubarTitle)
  self._menubar:setTooltip("OCR: capture region or choose source")
  self._menubar:setMenu({
    {
      title = "OCR…",
      fn = function()
        self:runDefaultInputFlow()
      end,
    },
    {
      title = "OCR settings…",
      fn = function()
        self:openSettingsPanel()
      end,
    },
  })
  return self
end

function obj:bindHotkeys(mapping)
  local m = mapping or {}
  local capture = m.capture or { { self.hotkey.mods, self.hotkey.key, function() self:captureAndCopy() end } }
  local row = capture[1]
  if not row or type(row[1]) ~= "table" or type(row[2]) ~= "string" or row[2] == "" or type(row[3]) ~= "function" then
    self.logger.w("bindHotkeys: invalid capture mapping; using default hotkey table")
    row = { self.hotkey.mods, self.hotkey.key, function() self:captureAndCopy() end }
  end

  if self._hotkey then
    self._hotkey:delete()
    self._hotkey = nil
  end
  self._hotkey = hs.hotkey.bind(row[1], row[2], row[3])
  self.logger.i("Bound hotkey: " .. hs.inspect(row[1]) .. " + " .. tostring(row[2]))
  return self
end

function obj:start()
  self:refreshMenubarItem()
  return self
end

function obj:stop()
  self:_closeUi()
  if self._hotkey then
    self._hotkey:delete()
    self._hotkey = nil
  end
  if self._menubar then
    self._menubar:delete()
    self._menubar = nil
  end
  self:cancel()
  return self
end

function obj:cancel()
  if self._captureTask then
    self._captureTask:terminate()
    self._captureTask = nil
  end
  if self._ocrTask then
    self._ocrTask:terminate()
    self._ocrTask = nil
  end
end

function obj:_resolveOcrBackend()
  local spoonPath = hs.spoons.scriptPath()
  local swiftScript = spoonPath .. "/ocr.swift"
  if fileExists(swiftScript) and commandExists("swift") then
    return {
      kind = "vision_swift",
      cmd = "swift",
      args = { swiftScript },
    }
  end

  if commandExists("tesseract") then
    return {
      kind = "tesseract",
      cmd = "tesseract",
      args = {},
    }
  end

  return nil
end

function obj:_taskNew(cmd, args, callback)
  local resolved = resolveCommandPath(cmd) or cmd
  self.logger.i("Launching task: " .. tostring(resolved) .. " " .. joinArgs(args))

  if resolved:sub(1, 1) == "/" and not isExecutable(resolved) then
    self.logger.e("Launch path not executable: " .. tostring(resolved))
    notify(self.notificationTitle, "Cannot run: " .. tostring(resolved) .. "\nCheck it exists + is executable.")
    return nil
  end

  local task = hs.task.new(resolved, callback, args)
  if not task then
    self.logger.e("hs.task.new returned nil for: " .. tostring(resolved))
    notify(
      self.notificationTitle,
      "Failed to start:\n" .. tostring(resolved) .. "\n\nLikely fixes:\n- System Settings → Privacy & Security → Screen Recording → enable Hammerspoon\n- Accessibility → enable Hammerspoon\n- Reload Hammerspoon config"
    )
    return nil
  end
  return task
end

function obj:captureAndCopy()
  if self._captureTask or self._ocrTask then
    notify(self.notificationTitle, "Already running")
    return
  end

  local imgPath = tmpPath("ocr_region_" .. tostring(hs.host.uuid() or "host") .. ".png")

  notify(self.notificationTitle, "Select a region… (Esc to cancel)")

  -- Workaround: some setups log `hs.task:launch() ... launch path not accessible`
  -- when launching `/usr/sbin/screencapture` directly. Launching via `/bin/sh -lc`
  -- avoids that by executing a known-accessible binary and letting the shell exec.
  local captureCmd = string.format("%q -i -s -x %q", "/usr/sbin/screencapture", imgPath)

  self._captureTask = self:_taskNew(
    "/bin/sh",
    { "-lc", captureCmd },
    function(exitCode, _stdout, stderr)
      self._captureTask = nil

      -- Common cancel case: user presses Esc
      if exitCode ~= 0 then
        self.logger.i("Capture cancelled/failed (exit " .. tostring(exitCode) .. "): " .. tostring(stderr))
        notify(self.notificationTitle, "Cancelled")
        tryRemoveTempOcrFile(imgPath)
        return
      end

      if not isPlausibleScreenCaptureFile(imgPath) then
        self.logger.w("screencapture produced no valid PNG (exit 0); stderr: " .. tostring(stderr))
        notify(self.notificationTitle, "No image captured (try again or check Screen Recording permission for Hammerspoon)")
        tryRemoveTempOcrFile(imgPath)
        return
      end

      self:_runOcr(imgPath)
    end
  )

  if not self._captureTask then
    return
  end

  self._captureTask:start()
end

function obj:ocrImageAtPath(imagePath)
  if self._captureTask or self._ocrTask then
    notify(self.notificationTitle, "Already running")
    return
  end
  if type(imagePath) ~= "string" or imagePath == "" then
    notify(self.notificationTitle, "Missing image path")
    return
  end
  if not fileExists(imagePath) then
    notify(self.notificationTitle, "Image not found")
    return
  end
  if not isNonEmptyReadableFile(imagePath) then
    notify(self.notificationTitle, "Image file is empty or unreadable")
    return
  end

  notify(self.notificationTitle, "Running OCR…")
  self:_runOcr(imagePath)
end

function obj:ocrClipboardImage()
  if self._captureTask or self._ocrTask then
    notify(self.notificationTitle, "Already running")
    return
  end

  local img = hs.pasteboard.readImage()
  if not img then
    notify(self.notificationTitle, "Clipboard does not contain an image")
    return
  end

  local imgPath = tmpPath("ocr_clipboard_" .. tostring(hs.host.uuid() or "host") .. ".png")
  local ok = img:saveToFile(imgPath)
  if not ok then
    notify(self.notificationTitle, "Failed to save clipboard image")
    return
  end
  if not isNonEmptyReadableFile(imgPath) then
    notify(self.notificationTitle, "Clipboard image saved as empty file")
    tryRemoveTempOcrFile(imgPath)
    return
  end

  notify(self.notificationTitle, "Running OCR…")
  self:_runOcr(imgPath)
end

function obj:ocrPickImageFile()
  local path = pickImageFileApplescript("Choose image to OCR", self.outputFolder or (os.getenv("HOME") .. "/Downloads"))
  if type(path) == "string" then
    self:ocrImageAtPath(path)
  end
end

function obj:_runOcr(imgPath)
  if type(imgPath) ~= "string" or imgPath == "" or not fileExists(imgPath) then
    notify(self.notificationTitle, "OCR image path is missing")
    tryRemoveTempOcrFile(imgPath)
    return
  end

  local backend = self:_resolveOcrBackend()
  if not backend then
    notify(self.notificationTitle, "No OCR backend found (need swift or tesseract)")
    tryRemoveTempOcrFile(imgPath)
    return
  end

  local ocrCmd
  if backend.kind == "vision_swift" then
    local spoonPath = hs.spoons.scriptPath()
    local swiftScript = spoonPath .. "/ocr.swift"
    ocrCmd = string.format("%q %q %q", "/usr/bin/swift", swiftScript, imgPath)
  elseif backend.kind == "tesseract" then
    ocrCmd = string.format("%q %q stdout", "tesseract", imgPath)
  end

  if not ocrCmd then
    notify(self.notificationTitle, "OCR backend misconfigured")
    tryRemoveTempOcrFile(imgPath)
    return
  end

  local function onOcrDone(exitCode, stdout, stderr)
    self._ocrTask = nil

    local function cleanupCaptureFile()
      tryRemoveTempOcrFile(imgPath)
    end

    if exitCode ~= 0 then
      self.logger.e("OCR failed (exit " .. tostring(exitCode) .. "): " .. tostring(stderr))
      notify(self.notificationTitle, userFacingOcrFailureMessage(exitCode, stderr))
      cleanupCaptureFile()
      return
    end

    local text = trim(stdout or "")
    if text == "" then
      local hint = trim(stderr or "")
      if hint ~= "" then
        self.logger.i("OCR produced empty text; stderr: " .. hint)
      end
      notify(self.notificationTitle, "No text detected in image")
      cleanupCaptureFile()
      return
    end

    cleanupCaptureFile()

    local action = normalizeOutputAction(self.outputAction, self.logger)
    self:_applyOutputAction(action, text)
  end

  self._ocrTask = self:_taskNew("/bin/sh", { "-lc", ocrCmd }, onOcrDone)

  if not self._ocrTask then
    tryRemoveTempOcrFile(imgPath)
    return
  end

  self._ocrTask:start()
end

return obj
