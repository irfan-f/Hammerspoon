--- === Light Filter ===
---
--- Allow user to control the light filter present on their displays
---
--- Download:
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Light Filter"
obj.version = "0.1.0"
obj.author = "<irfan@email>"
obj.homepage = ""
obj.license = "MIT - https://opensource.org/licenses/MIT"

local lightFilter;
-- local localPath = "/Spoons/LightFilter.spoon/";
local isGammaNormal = false;
local lightFilterIcon = hs.image.systemImageNames.QuickLookTemplate;
local iconLocation;

local setLightFilterDisplay = function(state)
  if state then
    local myScreens = hs.screen.allScreens();
    -- Apply the light filter to all screens
    -- Loop through each screen and setGamma
    if myScreens then
      for i, myScreen in ipairs(myScreens) do
        myScreen:setGamma({
            blue = 0.3,
            green = 0.5,
            red = 0.6
          }, { alpha = 0.3,
          blue = 0.0,
          green = 0.0,
          red = 0.0
        }) -- Reduce the intensity of blue light
      end
    end

    isGammaNormal = false;
  else
    hs.screen.restoreGamma();
    isGammaNormal = true;
  end
end

-- Define the window style
local windowStyle =
  hs.webview.windowMasks.borderless
  | hs.webview.windowMasks.titled
  | hs.webview.windowMasks.resizable
  | hs.webview.windowMasks.closable
  | hs.webview.windowMasks.nonactivating;

local function createWebView(recta)
  -- Create a new webview
  iconLocation = lightFilter:frame();

  local html;
  if webview == nil then
    local userContentInjector = hs.webview.usercontent.new("menubarManager");
    userContentInjector:setCallback(function(message)
      hs.printf(hs.inspect(message));
    end)
    webview = hs.webview.new(hs.geometry.rect(iconLocation.x, iconLocation.y, 200, 100), { javaScriptEnabled = false, javaScriptCanOpenWindowsAutomatically = false, developerExtrasEnabled = true }, userContentInjector);
    webview:windowStyle(windowStyle);
    webview:allowTextEntry(true);
    webview:allowGestures(true);
    -- Set the HTML, CSS, and JavaScript
    local file = io.open(hs.spoons.resourcePath("init.html"), "r");
    html = file:read('a');
    file:close();

    -- Load the HTML into the webview
    webview:html(html);
  end
  -- Show the webview
  webview:show();
  webview:bringToFront(true);
end

local function lightFilterClicked()
  setLightFilterDisplay(isGammaNormal);
end

local menuOptions = {
  { title = "Toggle Light Filter", fn = lightFilterClicked },
  { title = "-" },
  { title = "Options", fn = createWebView},
}

function obj:init()
  lightFilter = hs.menubar.new(true, "lightfilter");
  lightFilter:setIcon(hs.image.imageFromName(lightFilterIcon))
  lightFilter:setClickCallback(lightFilterClicked);
  setLightFilterDisplay(isGammaNormal)
end

return obj