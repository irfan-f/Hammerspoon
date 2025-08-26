--- === MenubarManager ===
--- 
--- CURRENTLY WIP, Not used
---
--- This will provide a menubar item that will allow a user to manage any menubar items created through hammerspoon
---
--- Download:
local obj = {}
obj.__index = obj

--- @type hs.menubar | nil

-- Metadata
obj.name = "MenubarManager"
obj.version = "0.1.0"
obj.author = "<irfan@email>"
obj.homepage = ""
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- Count the number of special characters in a string
--- @param str string The string to count the special characters in
---
--- @return integer count The number of special characters in the string
--- Example:
---  * countSpecialChars("⌘⌃⌥up") -- Returns 3
local function countSpecialChars(str)
  local count = 0
  for i = 1, #str, 3 do
    local c = str:sub(i, i + 2)
    if not ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9')) then
      count = count + 1
    end
  end
  return count
end

local currentScreensRect
local webview = nil;
local keybindingsToShowUnparsed = hs.hotkey.getHotkeys();
local keybindingGroups = {};
local hotKeysByName = {};
local addedGroups = {};
for _, hotkey in pairs(keybindingsToShowUnparsed) do
  -- Extract the group from the hotkey message
  local group = string.match(hotkey.msg, ": (.-)%s%-")
  local hotkeyName = string.match(hotkey.msg, ": (.*)")
  if hotkeyName then
    hotKeysByName[hotkeyName] = hotkey;
  end
  if group and addedGroups[group] then
    -- Add the hotkey to the group
    table.insert(keybindingGroups[group].hotkeys, {["text"] = hotkey.msg, ["subText"] = hotkey.idx, ["key"] = countSpecialChars(hotkey.idx), ["enabled"] = hotkey.enabled})
  end
  if group and not addedGroups[group] then
    -- Add the group to the table if it's not already there
    keybindingGroups[group] = {["text"] = group, ["subText"] = "[group]", ["key"] = countSpecialChars(hotkey.idx), ["hotkeys"] = {}};
    table.insert(keybindingGroups[group].hotkeys, {["text"] = hotkey.msg, ["subText"] = hotkey.idx, ["key"] = countSpecialChars(hotkey.idx), ["enabled"] = hotkey.enabled})
    addedGroups[group] = true
  end
end

-- Define the window style
local windowStyle = hs.webview.windowMasks.utility
  | hs.webview.windowMasks.titled
  | hs.webview.windowMasks.resizable
  | hs.webview.windowMasks.closable
  | hs.webview.windowMasks.miniaturizable
  | hs.webview.windowMasks.nonactivating;
local function createWebView()
  -- Create a new webview
  currentScreensRect = hs.screen.mainScreen():frame();
  local html;
  if webview == nil then
    local userContentInjector = hs.webview.usercontent.new("menubarManager");
    userContentInjector:setCallback(function(message)
      local specifiedHotkey = hotKeysByName[message.body.hotkey.title];
      local enabledValueToBe = message.body.value;
      if enabledValueToBe then
        specifiedHotkey:enable();
      else
        specifiedHotkey:disable();
      end
    end)
    webview = hs.webview.new(hs.geometry.rect(currentScreensRect.w/4, currentScreensRect.h/4, currentScreensRect.w / 2, currentScreensRect.h / 2), { developerExtrasEnabled = true }, userContentInjector);
    webview:windowStyle(windowStyle);
    webview:allowTextEntry(true);
    webview:allowGestures(true);
    -- Set the HTML, CSS, and JavaScript
    local file = io.open(hs.spoons.resourcePath("settings.html"), "r");
    html = file:read('a');
    file:close();
    html = string.gsub(html, "1; // REPLACE_WITH_HOTKEY_GROUPS", hs.json.encode(keybindingGroups));

    -- Load the HTML into the webview
    webview:html(html);
  end
  -- Show the webview
  webview:show();
  webview:bringToFront(true);
end

local menubarItem;
local menuOptions = {
  { title = "Open Settings", fn = createWebView },
  { title = "-" },
  { title = "Quit HS", fn = function () hs.applescript('tell application "Hammerspoon" to quit') end},
}

local icon = hs.image.systemImageNames.SmartBadgeTemplate;
function obj:init()
  menubarItem = hs.menubar.new()
  menubarItem:setIcon(hs.image.imageFromName(icon));
  menubarItem:setMenu(menuOptions)
end

return obj
