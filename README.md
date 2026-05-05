# Irfan’s [Hammerspoon](https://www.hammerspoon.org/) setup

Personal **Lua** config and **Spoons** for daily macOS automation: windows, displays, menubar-driven controls, OCR, screen warmth, and more.

**Repo:** [github.com/irfan-f/Hammerspoon](https://github.com/irfan-f/Hammerspoon)

## Install

1. Install [Hammerspoon](https://www.hammerspoon.org/) and grant **Accessibility** (and any other prompts it needs).
2. Either copy this repo into `~/.hammerspoon/`, **or** keep the repo elsewhere and point Hammerspoon at its `init.lua` (see [Custom config path](#custom-config-path) below).
3. Reload the config from the Hammerspoon menu bar icon.

Spoons live under `Spoons/`. `init.lua` loads `config.lua` and wires everything together.

## Menubar

**MenubarManager** exposes a **single menu bar icon** that aggregates:

- **Toggles** registered by other Spoons (e.g. light filter, keep-awake).
- **Actions** such as **Window hotkeys…**, which opens a small web UI to **view** default window shortcuts and **record** new bindings (stored as overrides).
- Hammerspoon maintenance entries (e.g. reload, quit) from the manager menu.

So day-to-day control and hotkey discovery live in that menu instead of hunting through separate tray icons.

## Custom config path

By default Hammerspoon loads `~/.hammerspoon/init.lua`. To use a clone of this repo (or any other folder), set **`MJConfigFile`** to the **absolute path of your `init.lua`**:

```bash
defaults write org.hammerspoon.Hammerspoon MJConfigFile -string "/Users/you/Code/Codespace/Hammerspoon/init.lua"
```

Use your real path; keep the `-string` value quoted if it contains spaces. **Quit and reopen Hammerspoon** (or “Reload Config”) so it picks this up.

Hammerspoon resolves **`Spoons/`** and related paths **relative to the directory that contains that `init.lua`**, so the repo layout stays valid when it is not under `~/.hammerspoon/`.

### Undo (back to default)

Remove the override so Hammerspoon uses `~/.hammerspoon/init.lua` again:

```bash
defaults delete org.hammerspoon.Hammerspoon MJConfigFile
```

Restart Hammerspoon afterward.

### Alternative: symlink

You can instead symlink `~/.hammerspoon` at your repo (or symlink only `init.lua` + `Spoons` if you prefer). That avoids `defaults` entirely; use whichever fits your setup.

## Hotkeys (overview)

**Source of truth:** `config.lua` — each Spoon’s `hotkey` table and `enabled` flags live there.

Defaults in this repo include (when enabled):

| Area | Shortcut | Notes |
|------|-----------|--------|
| Display controls (ModalControl) | `⌃` + `⌥` + `⌘` + `B` | Modal: warmth / brightness keys; see on-screen hint |
| Light filter | `⌘` + `⌥` + `L` | Toggle / adjust in Spoon + menubar |
| Keep awake (Caffeinate) | `⌘` + `⌥` + `C` | |
| OCR | `⌘` + `⌥` + `⇧` + `O` | |
| Window layout | `⇧` + `⌘` + arrows, `Return`, `1`–`3`, … | See **Menubar → Window hotkeys…** for the full list and remapping |

Change or disable any of these in `config.lua`, then reload Hammerspoon.
