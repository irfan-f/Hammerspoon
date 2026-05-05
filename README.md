# Irfan’s [Hammerspoon](https://www.hammerspoon.org/) setup

Personal **Lua** config and **Spoons** for daily macOS automation: windows, displays, keyboard-driven search, menubar helpers, OCR, screen warmth, and more.

**Repo:** [github.com/irfan-f/Hammerspoon](https://github.com/irfan-f/Hammerspoon)

## Install

1. Install [Hammerspoon](https://www.hammerspoon.org/) and grant **Accessibility** (and any other prompts it needs).  
2. Clone this repo **or** copy its contents into `~/.hammerspoon/` (back up your existing config first).  
3. Reload the Hammerspoon config from the menu bar icon.

Spoons live under `Spoons/` (e.g. `WindowManagement`, `MenubarManager`, `OCRTextExtractor`, `LightFilter`, `Caffeinate`, and others). `init.lua` wires them together.

## Menu bar manager

Work in progress: a menubar-driven way to turn shortcuts on/off and tweak visuals without editing Lua for every change.

## Handy shortcuts

- **Keybind search** — `ctrl` + `option` + `command` + `space`  
- **Full-screen window** — `shift` + `command` + `return`  
- **Display switch** — `shift` + `command` + `1` … `n` (monitor index)  
