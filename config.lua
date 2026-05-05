-- Central configuration for this Hammerspoon setup.
-- Keep this file small and declarative; put behavior inside Spoons.

local config = {
  console = {
    clearOnStart = true,
  },

  logging = {
    defaultLevel = "info",
  },

  ui = {
    hotkeyAlertDuration = 0,
    alertAtScreenEdge = 0,
    alertTextAlignment = "center",
  },

  spoons = {
    MenubarManager = {
      enabled = true,
    },
    ModalControl = {
      enabled = true,
      hotkey = { mods = { "cmd", "alt", "ctrl" }, key = "b" },
    },
    WindowManagement = {
      enabled = true,
      gridSize = 2,
      marginH = 0,
      marginW = 0,
      bindDefaultHotkeys = true,
    },
    LightFilter = {
      enabled = true,
      menuTitle = "Reduce blue light",
      adjustTitle = "Settings",
      brightnessBoostTitle = "Boost brightness",
      -- MenubarManager: separate section from "Light filter" (optional overrides)
      brightnessMenubarGroup = "Brightness boost",
      brightnessMenubarGroupOrder = 11,
      -- 90 matches the old hardcoded tint level
      defaultWarmth = 90,
      hotkey = { mods = { "cmd", "option" }, key = "L" },
      showMenubarExtra = false,
      menubarShortTitle = "☀",
    },
    Caffeinate = {
      enabled = true,
      menuTitle = "Keep display awake",
      settingsTitle = "Settings",
      hotkey = { mods = { "cmd", "option" }, key = "C" },
    },
    BrightnessPlus = {
      enabled = false,
      menuTitle = "Brightness++",
      adjustTitle = "Settings",
      defaultLevel = 0,
      hotkey = { mods = { "cmd", "option" }, key = "B" },
      showMenubarExtra = false,
      menubarShortTitle = "B+",
    },
    ActivityAdvisor = {
      enabled = false,
      menubarTitle = "Activity advisor…",
      group = "Activity",
      groupOrder = 35,
      hotkey = { mods = { "cmd", "option", "shift" }, key = "A" },
      watchCpuPercent = 8,
      pruneBackgroundCpuPercent = 3,
      pruneMemoryMb = 800,
    },
    OCRTextExtractor = {
      enabled = true,
      hotkey = { mods = { "cmd", "option", "shift" }, key = "O" },
      showMenubarItem = false,
      menubarTitle = "OCR",
      notificationTitle = "OCR",
      -- prompt | clipboard | textedit | folder
      outputAction = "prompt",
      -- prompt | screenshot | image | clipboard (OCR… menu)
      inputAction = "prompt",
      outputFolder = nil,
    },
  },
}

return config
