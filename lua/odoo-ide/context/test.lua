package.path = package.path .. ";/home/adruban/Workspace/Personal/odoo-ide.nvim/lua/?.lua"
package.path = package.path .. ";/home/adruban/Workspace/Personal/odoo-ide.nvim/lua/?/init.lua"

print("=== Testing Context Module ===\n")

local test_path = "/home/adruban/Workspace/Doodba_ENV/O17/odoo/custom/src/private/l10n_cl_fintoc/__manifest__.py"
print("Test 1: Reading manifest...")
local file = io.open(test_path, "r")
if file then
  local content = file:read("*all")
  file:close()
  
  local version_str = content:match("['\"]version['\"]%s*:%s*['\"](%d+)%.")
  print("  Manifest found: " .. test_path)
  print("  Version extracted: " .. (version_str or "nil"))
else
  print("  ERROR: Could not open manifest")
end

print("\nTest 2: Parsing model file...")
local model_path = "/home/adruban/Workspace/Doodba_ENV/O17/odoo/custom/src/private/l10n_cl_fintoc/models/fintoc_account_bank_request.py"
local model_file = io.open(model_path, "r")
if model_file then
  local content = model_file:read("*all")
  model_file:close()
  
  local model_name = content:match("_name%s*=%s*['\"]([%w%.]+)['\"]")
  print("  Model name: " .. (model_name or "nil"))
  
  local field_count = 0
  for _ in content:gmatch("=%s*fields%.") do
    field_count = field_count + 1
  end
  print("  Fields found: " .. field_count)
else
  print("  ERROR: Could not open model file")
end

print("\n=== Tests Complete ===")
