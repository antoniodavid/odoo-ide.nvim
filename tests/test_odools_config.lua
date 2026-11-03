-- Portable regression tests for odools.toml generation.
--
-- Builds a minimal Doodba-like tree in a temporary directory, so the suite
-- verifies the generated TOML without needing a real project.
--
-- Run with: nvim --headless -u NONE -l tests/test_odools_config.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local doodba = require("odoo-ide.doodba")
local odools = require("odoo-ide.odools")

local failures = 0

local function check(label, expected, actual)
  local ok = expected == actual
  print((ok and "PASS" or "FAIL") .. ": " .. label)
  if not ok then
    print("  expected: " .. vim.inspect(expected))
    print("  actual:   " .. vim.inspect(actual))
    failures = failures + 1
  end
end

local function check_true(label, condition, detail)
  print((condition and "PASS" or "FAIL") .. ": " .. label)
  if not condition then
    if detail then
      print("  detail: " .. vim.inspect(detail))
    end
    failures = failures + 1
  end
end

local function write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local fd = assert(io.open(path, "w"))
  fd:write(content)
  fd:close()
end

local base = vim.fn.fnamemodify(vim.fn.tempname(), ":p:h") .. "/odoo-ide-odools-test"
vim.fn.delete(base, "rf")

local root = base .. "/env"
local src = root .. "/odoo/custom/src"

write_file(root .. "/common.yaml", 'version: "2.4"\n')
write_file(src .. "/odoo/odoo-bin", "\n")
vim.fn.mkdir(src .. "/odoo/addons", "p")
write_file(src .. "/private/test_addon/__manifest__.py", "{'name': 'test_addon', 'version': '17.0.1.0.0'}\n")
write_file(src .. "/oca-repo/sale_addon/__manifest__.py", "{'name': 'sale_addon', 'version': '17.0.1.0.0'}\n")
write_file(src .. "/addons.yaml", 'oca-repo:\n  - "*"\n')
-- Repositories with no modules must not be added.
vim.fn.mkdir(src .. "/empty-repo", "p")

vim.cmd("cd " .. vim.fn.fnameescape(root))
vim.cmd("enew")

check("Doodba root", root, doodba.find_root())
check("Doodba detected", true, doodba.is_doodba())

local paths = doodba.get_paths()
local seen = {}
for _, path in ipairs(paths) do
  seen[path] = true
end
check_true("paths: odoo core addons", seen[src .. "/odoo/addons"])
check_true("paths: private modules", seen[src .. "/private"])
check_true("paths: repo from addons.yaml", seen[src .. "/oca-repo"])
check_true("paths: empty repo excluded", not seen[src .. "/empty-repo"])

local content, err = odools.generate_config({ profile_name = "main" })
check("generate_config error", nil, err)
check_true("generated content", type(content) == "string", content)
content = content or ""

check_true("toml: config table", content:find("%[%[config%]%]") ~= nil)
check_true("toml: profile name", content:find('name = "main"') ~= nil)
check_true("toml: relative odoo path", content:find('odoo_path = "./odoo/custom/src/odoo"', 1, true) ~= nil)
check_true("toml: relative addons paths", content:find('"./odoo/custom/src/private"', 1, true) ~= nil)
check_true("toml: addons.yaml repo included", content:find('"./odoo/custom/src/oca-repo"', 1, true) ~= nil)
check_true("toml: no absolute paths", content:find('"/', 1, true) == nil, content)
check_true("toml: no double slashes", content:find("//", 1, true) == nil, content)

local ok, written = odools.write_config({})
check("write_config status", true, ok)
check("write_config path", root .. "/odools.toml", written)
check("config on disk", 1, vim.fn.filereadable(root .. "/odools.toml"))
check("config lookup", root .. "/odools.toml", odools.get_config_path())

local again, message = odools.write_config({})
check("write_config without force", true, again)
check_true("write_config keeps existing file", tostring(message):find("already exists", 1, true) ~= nil, message)

-- Outside a Doodba tree the module must refuse instead of writing anywhere.
local plain = base .. "/plain"
vim.fn.mkdir(plain .. "/odoo/custom/src", "p")
vim.cmd("cd " .. vim.fn.fnameescape(plain))
vim.cmd("enew")

local no_content, no_err = odools.generate_config({})
check("outside Doodba content", nil, no_content)
check("outside Doodba error", "Not in a Doodba project", no_err)

vim.cmd("cd /")
vim.fn.delete(base, "rf")

print("")
if failures == 0 then
  print("=== All odools config tests passed ===")
else
  print("=== " .. failures .. " odools config test(s) failed ===")
  os.exit(1)
end
