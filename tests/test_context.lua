-- Test script for context detection module
-- Run with: nvim --headless -u NONE -c "lua dofile('tests/test_context.lua')"

-- Add plugin to path
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local context = require("odoo-ide.context")

-- Mock vim functions for headless testing
if not vim then
  vim = {
    fn = {
      expand = function(s)
        if s == "%:p:h" or s == "%:p" then
          return "/home/adruban/Workspace/Doodba_ENV/O17/odoo/custom/src/private/l10n_cl_fintoc/models"
        end
        return ""
      end,
      findfile = function(name, path)
        if name == "__manifest__.py" then
          return "/home/adruban/Workspace/Doodba_ENV/O17/odoo/custom/src/private/l10n_cl_fintoc/__manifest__.py"
        end
        return ""
      end,
      fnamemodify = function(path, mod)
        if mod == ":p" then return path end
        if mod == ":h" then return path:match("(.*/)")  end
        return path
      end,
    },
    api = {
      nvim_buf_get_lines = function()
        return {
          "from odoo import fields, models",
          "",
          "class FintocAccountBankRequest(models.Model):",
          "    _name = 'fintoc.account.bank.request'",
          "    _description = 'Accounts registered in fintoc'",
          "    name = fields.Char(string='Code')",
          "    bank_id = fields.Many2one('res.bank')",
          "    amount = fields.Float(compute='_compute_amount')",
        }
      end,
    },
    bo = {
      filetype = "python"
    },
    notify = function(msg, level)
      print("[NOTIFY] " .. tostring(msg))
    end,
    inspect = function(t)
      local function serialize(tbl, indent)
        indent = indent or ""
        local result = "{\n"
        for k, v in pairs(tbl) do
          result = result .. indent .. "  " .. tostring(k) .. " = "
          if type(v) == "table" then
            result = result .. serialize(v, indent .. "  ")
          else
            result = result .. tostring(v)
          end
          result = result .. ",\n"
        end
        return result .. indent .. "}"
      end
      return serialize(t)
    end,
    loop = {
      now = function() return os.time() * 1000 end
    }
  }
end

print("=== Testing odoo-ide.nvim context module ===\n")

-- Test 1: find_manifest
print("Test 1: find_manifest()")
local manifest = context.find_manifest()
print("  Result: " .. tostring(manifest))
assert(manifest ~= nil, "FAIL: manifest should not be nil")
print("  PASS\n")

-- Test 2: get_odoo_version
print("Test 2: get_odoo_version()")
local version = context.get_odoo_version()
print("  Result: " .. tostring(version))
assert(version == 17, "FAIL: version should be 17, got " .. tostring(version))
print("  PASS\n")

-- Test 3: get_file_location
print("Test 3: get_file_location()")
local location = context.get_file_location()
print("  Result: " .. tostring(location))
assert(location == "models", "FAIL: location should be 'models', got " .. tostring(location))
print("  PASS\n")

-- Test 4: get_model_info
print("Test 4: get_model_info()")
local model_info = context.get_model_info()
print("  name: " .. tostring(model_info.name))
print("  type: " .. tostring(model_info.type))
print("  fields: " .. #model_info.fields)
assert(model_info.name == "fintoc.account.bank.request", "FAIL: model name mismatch")
assert(model_info.type == "Model", "FAIL: model type should be Model")
print("  PASS\n")

-- Test 5: find_orphan_computes  
print("Test 5: find_orphan_computes()")
local orphans = context.find_orphan_computes()
print("  Orphan computes found: " .. #orphans)
for _, o in ipairs(orphans) do
  print("    - " .. o.method .. " (field: " .. o.field .. ")")
end
assert(#orphans >= 1, "FAIL: should find at least 1 orphan compute")
print("  PASS\n")

-- Test 6: get_context (full)
print("Test 6: get_context() - Full context")
local ctx = context.get_context()
print("  version: " .. tostring(ctx.version))
print("  location: " .. tostring(ctx.location))
print("  model.name: " .. tostring(ctx.model.name))
print("  filetype: " .. tostring(ctx.filetype))
print("  PASS\n")

print("=== All tests passed! ===")
