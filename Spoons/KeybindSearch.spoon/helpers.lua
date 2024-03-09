--- === KeybindSearch Helpers ===
---
--- This file contains helper functions for the KeybindSearch spoon
---
local helpers = {}

--- Key stroke function
--- @param modifiers table table of modifiers
---
--- @param character string string of the character to type
--- Example:
---  * doKeyStroke({"cmd", "alt"}, "t")
function helpers:doKeyStroke(modifiers, character)
  if type(modifiers) == 'table' then
      local event = hs.eventtap.event

      for _, modifier in pairs(modifiers) do
          event.newKeyEvent(modifier, true):post()
      end

      event.newKeyEvent(character, true):post()
      event.newKeyEvent(character, false):post()

      for i = #modifiers, 1, -1 do
          event.newKeyEvent(modifiers[i], false):post()
      end
  end
end

--- Count the number of special characters in a string
--- @param str string The string to count the special characters in
---
--- @return integer count The number of special characters in the string
--- Example:
---  * countSpecialChars("⌘⌃⌥up") -- Returns 3
function helpers:countSpecialChars(str)
  local count = 0
  for i = 1, #str, 3 do
    local c = str:sub(i, i + 2)
    if not ((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9')) then
      count = count + 1
    end
  end
  return count
end

--- A mapping from Unicode characters to key names
---
--- Note:
---  * Add more mappings as needed
helpers.unicodeToKey = {
  ["⌘"] = "cmd",
  ["⇧"] = "shift",
  ["⌥"] = "alt",
  ["⌃"] = "ctrl",
}

return helpers
