--- === ActivityAdvisor ===
--- Non–Apple/OS GUI apps: CPU/RSS from ps, watch/prune hints, webview UI.

local obj = {}
obj.__index = obj

obj.name = "ActivityAdvisor"
obj.version = "0.2.0"
obj.author = "Irfan F."
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("ActivityAdvisor")

obj.watchCpuPercent = 8
obj.pruneBackgroundCpuPercent = 3
obj.pruneMemoryMb = 800

obj.hotkey = nil
obj._hotkey = nil

local panelWebview = nil
local panelInjector = nil
local panelWebviewReady = false

local windowStyle = hs.webview.windowMasks.borderless
  | hs.webview.windowMasks.titled
  | hs.webview.windowMasks.resizable
  | hs.webview.windowMasks.closable

local function isAppleOrOSExcluded(app)
  local bid = app:bundleID()
  if type(bid) == "string" and bid ~= "" then
    if bid:match("^com%.apple%.") then
      return true
    end
    return false
  end
  local path = app:path()
  if type(path) ~= "string" or path == "" then
    return false
  end
  if
    path:match("^/System/Applications/")
    or path:match("^/System/Library/CoreServices/")
    or path:match("^/Library/Apple/")
  then
    return true
  end
  return false
end

local function trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- One `ps -ax` scan (rss KB on macOS); batched `ps -p` is unreliable for GUI PIDs.
local function fetchPsStats(pidSet)
  if next(pidSet) == nil then
    return {}
  end

  local cmd = "/bin/ps -ax -o pid=,pcpu=,rss="
  local rc, stdout, stderr = hs.execute(cmd, true)
  if rc ~= 0 or type(stdout) ~= "string" then
    obj.logger.w("ps failed rc=%s err=%s", tostring(rc), tostring(stderr))
    return {}
  end

  local out = {}
  for line in stdout:gmatch("[^\r\n]+") do
    line = trim(line)
    if line ~= "" then
      local pidStr, pcpuStr, rssStr = line:match("^(%d+)%s+([%d%.]+)%s+(%d+)%s*$")
      if pidStr then
        local pid = tonumber(pidStr)
        local pcpu = tonumber(pcpuStr) or 0
        local rssKb = tonumber(rssStr) or 0
        if pid and pidSet[pid] then
          out[pid] = { pcpu = pcpu, rssKb = rssKb }
        end
      end
    end
  end
  return out
end

local function formatBundleForDisplay(bid)
  if type(bid) ~= "string" or bid == "" then
    return "(no bundle id)"
  end
  return bid
end

local function buildTags(app, pcpu, rssMb)
  local tags = {}
  if pcpu >= obj.watchCpuPercent then
    table.insert(tags, "watch: high CPU")
  end
  local notFront = not app:isFrontmost()
  local prune = notFront
    and (pcpu >= obj.pruneBackgroundCpuPercent or rssMb >= obj.pruneMemoryMb)
  if prune then
    table.insert(tags, "prune candidate")
  end
  return tags
end

function obj:_gatherPanelState()
  local apps = hs.application.runningApplications()
  local candidates = {}
  local pidSet = {}

  for _, app in ipairs(apps) do
    if not isAppleOrOSExcluded(app) then
      local pid = app:pid()
      if pid and pid > 0 then
        pidSet[pid] = true
        table.insert(candidates, app)
      end
    end
  end

  local stats = fetchPsStats(pidSet)
  local rows = {}

  for _, app in ipairs(candidates) do
    local pid = app:pid()
    local st = stats[pid] or { pcpu = 0, rssKb = 0 }
    local rssMb = math.floor(st.rssKb / 1024 + 0.5)
    local name = app:name() or ("PID " .. tostring(pid))
    local bid = app:bundleID()
    local tags = buildTags(app, st.pcpu, rssMb)
    local tagStr = #tags > 0 and table.concat(tags, " · ") or ""

    table.insert(rows, {
      pid = pid,
      name = name,
      pcpu = st.pcpu,
      rssMb = rssMb,
      bundleID = type(bid) == "string" and bid or "",
      bundleDisplay = formatBundleForDisplay(bid),
      tagStr = tagStr,
    })
  end

  table.sort(rows, function(a, b)
    return a.pcpu > b.pcpu
  end)

  return { rows = rows }
end

function obj:_buildPanelHtml()
  local path = hs.spoons.scriptPath() .. "/advisor_panel.html"
  local file = io.open(path, "r")
  local html
  if file then
    html = file:read("a")
    file:close()
  else
    html = "<html><body>Missing advisor_panel.html</body></html>"
  end
  return html
end

function obj:_flushPanelBoot()
  if not panelWebview then
    return
  end
  local state = self._pendingPanelState
  if type(state) ~= "table" then
    return
  end
  local json = hs.json.encode(state)
  local js = "(function(){var s=" .. json .. ";if(typeof boot==='function')boot(s);})()"
  pcall(function()
    panelWebview:evaluateJavaScript(js)
  end)
end

function obj:_ensurePanelWebview()
  if panelWebview then
    return
  end

  panelInjector = hs.webview.usercontent.new("activityAdvisor")
  panelInjector:setCallback(function(message)
    if type(message) ~= "table" or type(message.body) ~= "table" then
      return
    end
    local t = message.body.type
    if t == "activate" then
      local pid = tonumber(message.body.pid)
      if pid then
        local a = hs.application.applicationForPID(pid)
        if a then
          a:activate()
        end
      end
    elseif t == "refresh" then
      obj._pendingPanelState = obj:_gatherPanelState()
      obj:_flushPanelBoot()
    end
  end)

  local mousePos = hs.mouse.absolutePosition()
  local w, h = 720, 520
  panelWebview = hs.webview.new(hs.geometry.rect(mousePos.x - w / 2, mousePos.y - h / 2, w, h), {
    javaScriptEnabled = true,
    javaScriptCanOpenWindowsAutomatically = false,
    developerExtrasEnabled = true,
  }, panelInjector)
  panelWebview:windowStyle(windowStyle)
  panelWebview:windowTitle("Activity Advisor")
  panelWebview:allowTextEntry(true)
  panelWebview:allowGestures(false)
  panelWebview:navigationCallback(function(action, wv, _nid, _err)
    if action == "didFinishNavigation" and wv == panelWebview then
      panelWebviewReady = true
      obj:_flushPanelBoot()
    end
  end)
  panelWebview:html(self:_buildPanelHtml())
end

function obj:showAdvisor()
  self._pendingPanelState = self:_gatherPanelState()
  local rows = self._pendingPanelState.rows
  if not rows or #rows == 0 then
    hs.alert.show("ActivityAdvisor: no non-system apps found.")
    return
  end

  self:_ensurePanelWebview()
  panelWebview:show()
  panelWebview:bringToFront(true)

  if panelWebviewReady then
    self:_flushPanelBoot()
  end
end

function obj:bindHotkeys()
  if self._hotkey then
    self._hotkey:delete()
    self._hotkey = nil
  end
  if not self.hotkey or type(self.hotkey.mods) ~= "table" or type(self.hotkey.key) ~= "string" then
    return self
  end
  self._hotkey = hs.hotkey.bind(self.hotkey.mods, self.hotkey.key, function()
    self:showAdvisor()
  end)
  return self
end

function obj:init()
  return self
end

return obj
