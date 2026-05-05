-- Shared display effects pipeline (gamma/blackpoint).
-- Ensures only one place writes to hs.screen:setGamma()/restoreGamma().

local M = {}

M.logger = hs.logger.new("DisplayEffects")

local isActive = false
local computeFn = nil
local persistEnabled = true

local persistKey = "DisplayEffects.persistEnabled"

local screenWatcher = nil
local wakeWatcher = nil
local reapplyTimer = nil

local function stopTimer()
  if reapplyTimer then
    reapplyTimer:stop()
    reapplyTimer = nil
  end
end

local function scheduleReapply(delaySeconds)
  stopTimer()
  reapplyTimer = hs.timer.doAfter(delaySeconds or 0.1, function()
    M.apply()
  end)
end

function M.getPersistEnabled()
  return persistEnabled
end

function M.setPersistEnabled(v)
  persistEnabled = v and true or false
  if persistEnabled then
    hs.settings.set(persistKey, true)
  else
    hs.settings.set(persistKey, false)
  end
end

function M.loadPersistEnabled(defaultValue)
  local v = hs.settings.get(persistKey)
  if type(v) ~= "boolean" then
    persistEnabled = defaultValue and true or false
    return persistEnabled
  end
  persistEnabled = v
  return persistEnabled
end

function M.setCompute(fn)
  computeFn = fn
end

function M.apply()
  if not isActive or not computeFn then
    return
  end

  local ok, gamma, alpha = pcall(computeFn)
  if not ok then
    M.logger.w("computeFn failed; disabling effects")
    M.disable()
    return
  end

  alpha = alpha or 0.0

  local screens = hs.screen.allScreens()
  if not screens then
    return
  end
  for _, s in ipairs(screens) do
    s:setGamma(gamma, { alpha = alpha, red = 0.0, green = 0.0, blue = 0.0 })
  end
end

function M.disable()
  isActive = false
  hs.screen.restoreGamma()
end

function M.enable()
  if isActive then
    return
  end
  isActive = true
  M.apply()
end

function M.isEnabled()
  return isActive
end

function M.startWatchers()
  if screenWatcher == nil then
    screenWatcher = hs.screen.watcher.new(function()
      if isActive then
        scheduleReapply(0.2)
      end
    end)
    screenWatcher:start()
  end

  if wakeWatcher == nil then
    wakeWatcher = hs.caffeinate.watcher.new(function(eventType)
      if not isActive then
        return
      end
      if
        eventType == hs.caffeinate.watcher.systemDidWake
        or eventType == hs.caffeinate.watcher.screensDidWake
      then
        scheduleReapply(0.5)
      end
    end)
    wakeWatcher:start()
  end
end

return M
