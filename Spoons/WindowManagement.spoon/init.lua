--- === WindowManagement ===
---
--- Provide functions to move windows between displays and change window placement and sizing.
---
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "WindowManagement"
obj.version = "0.1.0"
obj.author = "Irfan F."
obj.license = "MIT - https://opensource.org/licenses/MIT"

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

  hs.grid.setGrid(self.GRID_SIZE .. 'x' .. self.GRID_SIZE)
  hs.grid.setMargins({marginW, marginH}) -- hs.geometry object with the horizontal and vertical margins

  self.screenPositions = {
    -- Halves
    upper = { x = 0, y = 0, w = self.GRID_SIZE, h = self.HALF_GRID_SIZE }, -- upper half
    lower = { x = 0, y = self.HALF_GRID_SIZE, w = self.GRID_SIZE, h = self.HALF_GRID_SIZE }, -- lower half
    left = { x = 0, y = 0, w = self.HALF_GRID_SIZE, h = self.GRID_SIZE }, --- left half
    right = { x = self.HALF_GRID_SIZE, y = 0, w = self.HALF_GRID_SIZE, h = self.GRID_SIZE }, -- right half
    -- Quarters
    upperLeft = { x = 0, y = 0, w = self.HALF_GRID_SIZE, h = self.HALF_GRID_SIZE }, -- upper left
    upperRight = { x = self.HALF_GRID_SIZE, y = 0, w = self.HALF_GRID_SIZE, h = self.HALF_GRID_SIZE }, -- upper right
    lowerLeft = { x = 0, y = self.HALF_GRID_SIZE, w = self.HALF_GRID_SIZE, h = self.HALF_GRID_SIZE }, -- lower left
    lowerRight = { x = self.HALF_GRID_SIZE, y = self.HALF_GRID_SIZE, w = self.HALF_GRID_SIZE, h = self.HALF_GRID_SIZE }, --- lower right
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

--- WindowManagement:bindDefaultHotkeys()
--- Method
--- Bind the default hotkeys
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
  -- Bind the maximize hotkey
  hs.hotkey.bind({"shift", "cmd"}, "return", "Window - Maximize", function () self:maximizeWindow() end)
  -- Bind the move window to position hotkeys
  hs.hotkey.bind({"alt", "cmd"}, "left", "Window - Left", function () self:moveWindowToPosition(self.screenPositions.left) end)
  hs.hotkey.bind({"alt", "cmd"}, "up", "Window - Top", function() self:moveWindowToPosition(self.screenPositions.upper) end)
  hs.hotkey.bind({"alt", "cmd"}, "down", "Window - Bottom", function () self:moveWindowToPosition(self.screenPositions.lower) end)
  hs.hotkey.bind({"alt", "cmd"}, "right", "Window - Right", function () self:moveWindowToPosition(self.screenPositions.right) end)
  hs.hotkey.bind({"shift", "cmd"}, "left", "Window - Top Left", function () self:moveWindowToPosition(self.screenPositions.upperLeft) end)
  hs.hotkey.bind({"shift", "cmd"}, "up", "Window - Top Right", function () self:moveWindowToPosition(self.screenPositions.upperRight) end)
  hs.hotkey.bind({"shift", "cmd"}, "down", "Window - Bottom Left", function () self:moveWindowToPosition(self.screenPositions.lowerLeft) end)
  hs.hotkey.bind({"shift", "cmd"}, "right", "Window - Bottom Right", function () self:moveWindowToPosition(self.screenPositions.lowerRight) end)
  -- Bind the move window to display hotkeys
  hs.hotkey.bind({"shift", "cmd"}, "1", "Window - Display 1", function () self:moveWindowToDisplay(1) end)
  hs.hotkey.bind({"shift", "cmd"}, "2", "Window - Display 2", function () self:moveWindowToDisplay(2) end)
  hs.hotkey.bind({"shift", "cmd"}, "3", "Window - Display 3", function () self:moveWindowToDisplay(3) end)
end

return obj
