--- === MenubarManager ===
---
--- Single menubar icon aggregating toggles and actions registered by other Spoons.
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "MenubarManager"
obj.version = "0.1.0"
obj.author = "<irfan@email>"
obj.homepage = ""
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("MenubarManager")

local menubarItem

local registeredToggles = {}
local registeredActions = {}

local function normalizeGroup(group)
  if type(group) == "string" and group ~= "" then
    return group
  end
  return "Other"
end

--- MenubarManager:registerToggle(opts)
--- Method
--- Registers a checkbox-style toggle into the MenubarManager menu.
---
--- Parameters:
---  * opts - table with:
---    * id (string) unique identifier
---    * title (string) menu label
---    * get (function) -> boolean
---    * set (function) (boolean) -> nil
function obj:registerToggle(opts)
  if type(opts) ~= "table" then
    error("registerToggle expects a table")
  end
  if type(opts.id) ~= "string" or opts.id == "" then
    error("registerToggle requires a non-empty string id")
  end
  if type(opts.title) ~= "string" or opts.title == "" then
    error("registerToggle requires a non-empty string title")
  end
  if type(opts.get) ~= "function" or type(opts.set) ~= "function" then
    error("registerToggle requires get/set functions")
  end

  local hotkey = opts.hotkey
  if type(hotkey) ~= "string" or hotkey == "" then
    hotkey = nil
  end

  registeredToggles[opts.id] = {
    id = opts.id,
    title = opts.title,
    status = opts.status,
    get = opts.get,
    set = opts.set,
    group = normalizeGroup(opts.group),
    order = tonumber(opts.order),
    groupOrder = tonumber(opts.groupOrder),
    hotkey = hotkey,
  }

  self:refreshMenu()
end

--- MenubarManager:registerAction(opts)
--- Method
--- Registers a simple menu action (button) into the MenubarManager menu.
---
--- Parameters:
---  * opts - table with:
---    * id (string) unique identifier
---    * title (string) menu label
---    * fn (function) -> nil
function obj:registerAction(opts)
  if type(opts) ~= "table" then
    error("registerAction expects a table")
  end
  if type(opts.id) ~= "string" or opts.id == "" then
    error("registerAction requires a non-empty string id")
  end
  if type(opts.title) ~= "string" or opts.title == "" then
    error("registerAction requires a non-empty string title")
  end
  if type(opts.fn) ~= "function" then
    error("registerAction requires a function fn")
  end

  local hotkey = opts.hotkey
  if type(hotkey) ~= "string" or hotkey == "" then
    hotkey = nil
  end

  registeredActions[opts.id] = {
    id = opts.id,
    title = opts.title,
    status = opts.status,
    fn = opts.fn,
    group = normalizeGroup(opts.group),
    order = tonumber(opts.order),
    groupOrder = tonumber(opts.groupOrder),
    hotkey = hotkey,
  }

  self:refreshMenu()
end

--- Update the stored hotkey label for a registered toggle or action (e.g. after user rebinding in a settings webview).
function obj:setMenuEntryHotkey(id, hotkeyString)
  if type(id) ~= "string" or id == "" then
    return
  end
  local hk = (type(hotkeyString) == "string" and hotkeyString ~= "") and hotkeyString or nil
  local t = registeredToggles[id]
  if t then
    t.hotkey = hk
    self:refreshMenu()
    return
  end
  local a = registeredActions[id]
  if a then
    a.hotkey = hk
    self:refreshMenu()
  end
end

local function buildGroupedMenuItems()
  local groups = {}
  local groupOrder = {}
  local groupMeta = {}

  local function ensureGroup(name)
    if not groups[name] then
      groups[name] = { toggles = {}, actions = {} }
      table.insert(groupOrder, name)
    end
    return groups[name]
  end

  for _, t in pairs(registeredToggles) do
    table.insert(ensureGroup(t.group).toggles, t)
    groupMeta[t.group] = groupMeta[t.group] or { order = t.groupOrder }
  end
  for _, a in pairs(registeredActions) do
    table.insert(ensureGroup(a.group).actions, a)
    groupMeta[a.group] = groupMeta[a.group] or { order = a.groupOrder }
  end

  table.sort(groupOrder, function(a, b)
    local ao = (groupMeta[a] and groupMeta[a].order) or math.huge
    local bo = (groupMeta[b] and groupMeta[b].order) or math.huge
    if ao ~= bo then
      return ao < bo
    end
    return a < b
  end)

  local items = {}

  local function soleHotkeyForGroupHeader(group)
    local found = nil
    for _, t in ipairs(group.toggles) do
      if t.hotkey then
        if found then
          return nil
        end
        found = t.hotkey
      end
    end
    for _, a in ipairs(group.actions) do
      if a.hotkey then
        if found then
          return nil
        end
        found = a.hotkey
      end
    end
    return found
  end

  for _, groupName in ipairs(groupOrder) do
    local group = groups[groupName]

    local headerTitle = groupName
    local soleHotkey = soleHotkeyForGroupHeader(group)
    if soleHotkey then
      headerTitle = groupName .. "    " .. soleHotkey
    end
    table.insert(items, { title = headerTitle, disabled = true })

    table.sort(group.toggles, function(a, b)
      local ao = a.order or math.huge
      local bo = b.order or math.huge
      if ao ~= bo then
        return ao < bo
      end
      return a.title < b.title
    end)
    table.sort(group.actions, function(a, b)
      local ao = a.order or math.huge
      local bo = b.order or math.huge
      if ao ~= bo then
        return ao < bo
      end
      return a.title < b.title
    end)

    for _, t in ipairs(group.toggles) do
      local okGet, value = pcall(t.get)
      if not okGet then
        obj.logger.w("Toggle get failed for " .. t.id)
        value = false
      end

      local title = t.title
      if type(t.status) == "function" then
        local okStatus, status = pcall(t.status)
        if okStatus and type(status) == "string" and status ~= "" then
          title = title .. " (" .. status .. ")"
        end
      end

      table.insert(items, {
        title = title,
        checked = value and true or false,
        fn = function()
          local okCurrent, current = pcall(t.get)
          if not okCurrent then
            obj.logger.w("Toggle get failed for " .. t.id)
            return
          end
          local okSet = pcall(t.set, not current)
          if not okSet then
            obj.logger.w("Toggle set failed for " .. t.id)
            return
          end
          obj:refreshMenu()
        end,
      })
    end

    for _, a in ipairs(group.actions) do
      local title = a.title
      if type(a.status) == "function" then
        local okStatus, status = pcall(a.status)
        if okStatus and type(status) == "string" and status ~= "" then
          title = title .. " (" .. status .. ")"
        end
      end
      table.insert(items, {
        title = title,
        fn = function()
          local ok = pcall(a.fn)
          if not ok then
            obj.logger.w("Action failed for " .. a.id)
          end
        end,
      })
    end

    table.insert(items, { title = "-" })
  end

  if #items > 0 and items[#items].title == "-" then
    table.remove(items, #items)
  end

  return items
end

function obj:refreshMenu()
  if not menubarItem then
    return
  end

  local menuOptions = {}

  local featureItems = buildGroupedMenuItems()
  for _, item in ipairs(featureItems) do
    table.insert(menuOptions, item)
  end
  if #featureItems > 0 then
    table.insert(menuOptions, { title = "-" })
  end

  table.insert(menuOptions, { title = "Reload Hammerspoon", fn = hs.reload })
  table.insert(menuOptions, {
    title = "Quit HS",
    fn = function()
      hs.applescript('tell application "Hammerspoon" to quit')
    end,
  })

  menubarItem:setMenu(menuOptions)
end

local icon = hs.image.systemImageNames.SmartBadgeTemplate
function obj:init()
  menubarItem = hs.menubar.new()
  menubarItem:setIcon(hs.image.imageFromName(icon))
  self:refreshMenu()
end

return obj
