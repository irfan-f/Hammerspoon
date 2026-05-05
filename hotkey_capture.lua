--- Shared hotkey recording for hs.webview settings panels (hs.eventtap).
local M = {}

local pretty = { cmd = "⌘", ctrl = "⌃", option = "⌥", alt = "⌥", shift = "⇧" }

local function isValidHotkeyTable(hk)
  return type(hk) == "table" and type(hk.mods) == "table" and type(hk.key) == "string"
end

local function formatHotkeyString(hk)
  local out = ""
  for _, m in ipairs(hk.mods) do
    out = out .. (pretty[m] or m)
  end
  return out .. tostring(hk.key)
end

--- Human-readable shortcut for logs and webview (invalid → "(not set)").
function M.formatHotkey(hk)
  if not isValidHotkeyTable(hk) then
    return "(not set)"
  end
  return formatHotkeyString(hk)
end

--- Same string as formatHotkey for valid tables; invalid → nil (MenubarManager labels).
function M.formatMenubarHotkey(hk)
  if not isValidHotkeyTable(hk) then
    return nil
  end
  return formatHotkeyString(hk)
end

local modifierTapKeyNames = {
  cmd = true,
  shift = true,
  alt = true,
  ctrl = true,
  fn = true,
  rightcmd = true,
  rightshift = true,
  rightalt = true,
  rightctrl = true,
  capslock = true,
}

local function keyNameFromKeyCode(code)
  if type(code) ~= "number" then
    return nil
  end
  local candidates = {}
  for name, c in pairs(hs.keycodes.map) do
    if c == code and type(name) == "string" then
      table.insert(candidates, name)
    end
  end
  if #candidates == 0 then
    return nil
  end
  table.sort(candidates)
  for _, name in ipairs(candidates) do
    if #name == 1 then
      return name
    end
  end
  return candidates[1]
end

local function normalizeHotkeyKey(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local lk = string.lower(name)
  if modifierTapKeyNames[lk] or lk == "escape" then
    return nil
  end
  if #name == 1 then
    return string.upper(name)
  end
  return lk
end

local function modsFromEventFlags(flags)
  if type(flags) ~= "table" then
    return {}
  end
  local mods = {}
  if flags.cmd then
    table.insert(mods, "cmd")
  end
  if flags.ctrl or flags.rightctrl then
    table.insert(mods, "ctrl")
  end
  if flags.alt or flags.rightalt then
    table.insert(mods, "option")
  end
  if flags.shift or flags.rightshift then
    table.insert(mods, "shift")
  end
  return mods
end

function M.stopCapture(spoon)
  if spoon._hotkeyCaptureTimer then
    spoon._hotkeyCaptureTimer:stop()
    spoon._hotkeyCaptureTimer = nil
  end
  if spoon._hotkeyCaptureTap then
    spoon._hotkeyCaptureTap:stop()
    spoon._hotkeyCaptureTap = nil
  end
end

--- opts: notifyTitle (string), webview (hs.webview|nil), onSuccess(spoon, mods, key), onRefresh(spoon) optional
function M.startCapture(spoon, opts)
  M.stopCapture(spoon)
  local title = opts.notifyTitle or "Hotkey"
  local function n(text)
    hs.notify.new({ title = title, informativeText = text }):send()
  end

  if opts.webview then
    opts.webview:bringToFront(true)
  end
  n("Press new shortcut (Esc to cancel)")

  spoon._hotkeyCaptureTimer = hs.timer.doAfter(20, function()
    M.stopCapture(spoon)
    n("Hotkey capture timed out")
    if opts.onRefresh then
      opts.onRefresh(spoon)
    end
  end)

  spoon._hotkeyCaptureTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
    local flags = e:getFlags()
    local code = e:getKeyCode()
    local rawName = keyNameFromKeyCode(code)
    if not rawName then
      return false
    end

    if string.lower(rawName) == "escape" then
      M.stopCapture(spoon)
      n("Hotkey capture cancelled")
      if opts.onRefresh then
        opts.onRefresh(spoon)
      end
      return true
    end

    if modifierTapKeyNames[string.lower(rawName)] then
      return false
    end

    local key = normalizeHotkeyKey(rawName)
    if not key then
      return false
    end

    local mods = modsFromEventFlags(flags)
    if #mods == 0 then
      n("Include a modifier (⌘ ⌥ ⌃ ⇧)")
      return true
    end

    opts.onSuccess(spoon, mods, key)
    M.stopCapture(spoon)
    n("Hotkey: " .. M.formatHotkey({ mods = mods, key = key }))
    if opts.onRefresh then
      opts.onRefresh(spoon)
    end
    return true
  end)

  spoon._hotkeyCaptureTap:start()
end

return M
