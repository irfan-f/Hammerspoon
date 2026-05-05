-- Luacheck configuration for Hammerspoon config/Spoons.
-- https://luacheck.readthedocs.io/

std = "lua53"

globals = {
  "hs",
  "spoon",
}

ignore = {
  "631", -- max_line_length (handled by stylua)
  "212", -- unused argument (common for Spoon-style :methods)
}

files["**/Spoons/**/docs.json"] = { ignore = { "011" } } -- allow non-lua in tree
files["**/*.html"] = { ignore = { "011" } }

