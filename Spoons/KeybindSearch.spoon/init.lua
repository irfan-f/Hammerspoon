--- === KeybindSearch ===
---
--- This spoon offers an interactive way to view and navigate through all active keybindings.
---
local obj = {}
obj.__index = obj
local chooser
local hotkeys

local helpers = dofile(hs.spoons.scriptPath() .. "/helpers.lua")

-- Metadata
obj.name = "KeybindSearch"
obj.version = "0.1.0"
obj.author = "Irfan F."
obj.license = "MIT - https://opensource.org/licenses/MIT"

function obj:init()
  hotkeys = hs.hotkey.getHotkeys()
  if not hotkeys then
    hs.printf("No hotkeys found")
    return
  end

  -- Create a new chooser
  chooser = hs.chooser.new(function(choice)
    -- Handle the choice here
    if choice then
      if choice["subText"] == "[group]" then
        local group = choice["text"]
        local groupChoices = {}
        for _, hotkey in pairs(hotkeys) do
          local msg = hotkey.msg
          local idx = hotkey.idx
          local command = string.match(msg, ": (.*)")
          local modCount = choice["key"]
          local mods = string.sub(idx, 1, modCount * 3)
          local key = string.sub(idx, modCount * 3 + 1, idx:len())
          if string.find(command, group .. " -") then
            table.insert(groupChoices, {["text"] = command, ["subText"] = mods, ["key"] = key})
          end
        end
        chooser:choices(groupChoices)
        chooser:show()
      end
      if choice["subText"] ~= "[group]" then
        -- Convert the modifier string into a table of key names
        local mods = {}
        for i = 1, #choice["subText"], 3 do  -- Each Unicode character is 3 bytes
          local unicodeChar = choice["subText"]:sub(i, i + 2)
          local keyName = helpers.unicodeToKey[unicodeChar]
          hs.printf(keyName)
          hs.printf(unicodeChar)
          if keyName then
            table.insert(mods, keyName)
          end
        end
        local keykey = choice["key"]:lower()
        if hs.fnutils.contains(mods, "shift") and string.len(keykey) == 1 then
          keykey = keykey:upper()
        end
        hs.printf(keykey)
        helpers:doKeyStroke(mods, keykey)
        self:setGroupChoices()
      end
      -- chooser:show()
    end
  end)

  -- Set the sub text
  chooser:subTextColor({hex="#AAAAAA"})

  -- Set the placeholder text
  chooser:placeholderText("Search for a keybinding")

  -- Set the choices
  self:setGroupChoices()
end

-- Create a table to store the unique groups
function obj:setGroupChoices()
  local groups = {}
  local addedGroups = {}

  -- Iterate over the hotkeys
  for _, hotkey in pairs(hotkeys) do
    -- Extract the group from the hotkey message
    local group = string.match(hotkey.msg, ": (.-)%s%-")
    if group and not addedGroups[group] then
      -- Add the group to the table if it's not already there
      table.insert(groups, {["text"] = group, ["subText"] = "[group]", ["key"] = helpers:countSpecialChars(hotkey.idx)})
      addedGroups[group] = true
    end
  end
  chooser:choices(groups)
end

--- Show the chooser
function obj:show()
  chooser:show()
end

obj.chooser = chooser

return obj
