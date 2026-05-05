--- Shared helper: keep MenubarManager tray menu in sync when state changes
--- outside the menu (hotkeys, modal, mutual exclusion between spoons).
local M = {}

function M.refreshMenubarIfNeeded()
  local mm = spoon and spoon.MenubarManager
  if mm and type(mm.refreshMenu) == "function" then
    pcall(function()
      mm:refreshMenu()
    end)
  end
end

return M
