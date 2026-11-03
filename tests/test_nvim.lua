-- Test script for odoo-ide.nvim
-- Run with: nvim -u NONE -l tests/test_nvim.lua

-- Add plugin to rtp
vim.opt.rtp:prepend("/home/adruban/Workspace/Personal/odoo-ide.nvim")

print("=== Testing odoo-ide.nvim in Neovim ===\n")

local ok, odoo_ide = pcall(require, "odoo-ide")
if not ok then
  print("ERROR: Could not load odoo-ide module")
  print(odoo_ide)
  os.exit(1)
end
print("✓ odoo-ide module loaded")

local context_ok, context = pcall(require, "odoo-ide.context")
if not context_ok then
  print("ERROR: Could not load context module")
  os.exit(1)
end
print("✓ context module loaded")

vim.cmd("cd /home/adruban/Workspace/Doodba_ENV/O17/odoo/custom/src/private/l10n_cl_fintoc/models")
vim.cmd("edit fintoc_account_bank_request.py")

print("\n--- Testing context detection ---")
local ctx = context.get_context()
print("Version: " .. tostring(ctx.version))
print("Location: " .. ctx.location)
print("Filetype: " .. ctx.filetype)
print("Model name: " .. tostring(ctx.model.name))
print("Model type: " .. ctx.model.type)
print("Fields count: " .. #ctx.model.fields)

if ctx.version == 17 then
  print("\n✓ Version detection PASSED (expected 17)")
else
  print("\n✗ Version detection FAILED (expected 17, got " .. tostring(ctx.version) .. ")")
end

if ctx.location == "models" then
  print("✓ Location detection PASSED (expected models)")
else
  print("✗ Location detection FAILED (expected models, got " .. ctx.location .. ")")
end

print("\n--- Checking LuaSnip availability ---")
local luasnip_ok = pcall(require, "luasnip")
if luasnip_ok then
  print("✓ LuaSnip available")
  
  odoo_ide.setup()
  print("✓ odoo-ide.setup() completed")
  
  local ls = require("luasnip")
  local snippets = ls.get_snippets("python")
  local odoo_count = 0
  for _, snip in ipairs(snippets) do
    if snip.trigger and snip.trigger:match("^oo") then
      odoo_count = odoo_count + 1
    end
  end
  print("Odoo snippets loaded: " .. odoo_count)
else
  print("⚠ LuaSnip not available - skipping snippet tests")
  print("  (This is normal when running outside of Neovim config)")
end

print("\n=== Tests Complete ===")
