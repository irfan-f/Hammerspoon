--- === Caffeinate ===
---
--- Allow a user to force the display to stay awake or not, default menubar with option to hotkey
---
--- Download:
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Caffeinate"
obj.version = "0.1.0"
obj.author = "<irfan-f@gmail.com>"
obj.homepage = ""
obj.license = "MIT - https://opensource.org/licenses/MIT"

local caffeine;
local localPath = "/Spoons/Caffeinate.spoon/";
local function setCaffeineDisplay(state)
  local icon;
  if state then
    icon = hs.image.imageFromPath(hs.fs.pathToAbsolute("./") .. localPath .. "caffeine-on.pdf");
    caffeine:setIcon(icon);
  else
    icon = hs.image.imageFromPath(hs.fs.pathToAbsolute("./") .. localPath .. "caffeine-off.pdf");
    caffeine:setIcon(icon);
  end
end

local function caffeineClicked()
  setCaffeineDisplay(hs.caffeinate.toggle("displayIdle"))
end

function obj:init()
  caffeine = hs.menubar.new()
  if caffeine then
    caffeine:setClickCallback(caffeineClicked)
    setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
  end
end



return obj
