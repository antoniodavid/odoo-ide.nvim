-- Portable tests for the nvim-dap integration.
--
-- A fake `dap` module is injected so the suite can verify that a user's
-- adapter and configurations survive, and that path mappings cover core and
-- custom addons. No container is required.
--
-- Run with: nvim --headless -u NONE -l tests/test_dap_config.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local fake_dap = {
  adapters = {
    python = { type = "executable", command = "python-adapter" },
  },
  configurations = {
    python = { { type = "python", name = "User config" } },
  },
}

package.loaded["dap"] = fake_dap

local dap_mod = require("odoo-ide.dap")
local project = require("odoo-ide.project")

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

local function find_mapping(mappings, local_root)
  for _, mapping in ipairs(mappings) do
    if mapping.localRoot == local_root then
      return mapping
    end
  end
  return nil
end

-- Ports follow Doodba's convention.
check("debugpy port 17", 17899, dap_mod.debugpy_port(17))
check("debugpy port 18", 18899, dap_mod.debugpy_port(18))
check("debugpy port default", 17899, dap_mod.debugpy_port(nil))
check("web port 16", 16069, dap_mod.web_port(16))
check("web port default", 17069, dap_mod.web_port(nil))

-- Doodba fixture.
local base = vim.fn.fnamemodify(vim.fn.tempname(), ":p:h") .. "/odoo-ide-dap-test"
vim.fn.delete(base, "rf")

local root = base .. "/env"
local src = root .. "/odoo/custom/src"
local odoo_path = src .. "/odoo"

write_file(root .. "/common.yaml", 'services:\n  odoo:\n    build:\n      args:\n        ODOO_VERSION: "17.0"\n')
write_file(odoo_path .. "/odoo-bin", "\n")
write_file(odoo_path .. "/addons/sale/__manifest__.py", "{'name': 'sale'}\n")
write_file(odoo_path .. "/odoo/addons/base/__manifest__.py", "{'name': 'base'}\n")
write_file(src .. "/private/my_addon/__manifest__.py", "{'name': 'my_addon'}\n")
write_file(src .. "/oca-repo/sale_addon/__manifest__.py", "{'name': 'sale_addon'}\n")
vim.fn.mkdir(src .. "/empty_repo", "p")

vim.cmd("edit " .. vim.fn.fnameescape(src .. "/private/my_addon/__manifest__.py"))
project.reset()

local current = project.get()
check_true("project detected", current ~= nil)
check("project kind", "doodba", current and current.kind)

-- Path mappings.
local mappings = dap_mod.build_path_mappings(current)

local checkout_mapping = find_mapping(mappings, odoo_path)
check_true("mapping: checkout root", checkout_mapping ~= nil)
check(
  "mapping: checkout remote root",
  "/opt/odoo/custom/src/odoo",
  checkout_mapping and checkout_mapping.remoteRoot
)

local core_addon = find_mapping(mappings, odoo_path .. "/addons/sale")
check_true("mapping: core addon", core_addon ~= nil)
check("mapping: core addon remote", "/opt/odoo/auto/addons/sale", core_addon and core_addon.remoteRoot)

local bundled_addon = find_mapping(mappings, odoo_path .. "/odoo/addons/base")
check_true("mapping: bundled core addon", bundled_addon ~= nil)
check("mapping: bundled core addon remote", "/opt/odoo/auto/addons/base", bundled_addon and bundled_addon.remoteRoot)

local private_addon = find_mapping(mappings, src .. "/private/my_addon")
check_true("mapping: private addon", private_addon ~= nil)
check("mapping: private addon remote", "/opt/odoo/auto/addons/my_addon", private_addon and private_addon.remoteRoot)

local repo_addon = find_mapping(mappings, src .. "/oca-repo/sale_addon")
check_true("mapping: repo addon", repo_addon ~= nil)
check("mapping: repo addon remote", "/opt/odoo/auto/addons/sale_addon", repo_addon and repo_addon.remoteRoot)

check_true("mapping: no empty repo entries", find_mapping(mappings, src .. "/empty_repo") == nil)

-- Configurations must be additive: the user's adapter and configs survive.
dap_mod.reset()
dap_mod.ensure_configured()

check("user adapter untouched", "python-adapter", fake_dap.adapters.python.command)
check("user configuration kept", "User config", fake_dap.configurations.python[1].name)
check("python configuration count", 2, #fake_dap.configurations.python)

local odoo_config = fake_dap.configurations.python[2]
check("config: type", "odoo-python", odoo_config and odoo_config.type)
check("config: request", "attach", odoo_config and odoo_config.request)
check("config: port", 17899, odoo_config and odoo_config.port)
check_true("config: name mentions port", odoo_config and odoo_config.name:find("17899", 1, true) ~= nil)
check_true("config: mappings attached", odoo_config and #odoo_config.pathMappings == #mappings)
check("adapter: port", 17899, fake_dap.adapters["odoo-python"].port)
check("adapter: type", "server", fake_dap.adapters["odoo-python"].type)

-- The browser configuration is skipped when its adapter is missing.
check("javascript configs skipped", nil, fake_dap.configurations.javascript)

-- Re-running must not duplicate our entry.
dap_mod.reset()
dap_mod.ensure_configured()
check("configuration not duplicated", 2, #fake_dap.configurations.python)

-- With a browser adapter, the Odoo web configuration is added.
fake_dap.adapters["pwa-chrome"] = { type = "executable", command = "chrome" }
fake_dap.configurations.javascript = { { type = "pwa-chrome", name = "User JS" } }
dap_mod.reset()
dap_mod.ensure_configured()

check("javascript configuration count", 2, #fake_dap.configurations.javascript)
check("user javascript configuration kept", "User JS", fake_dap.configurations.javascript[1].name)
check("javascript configuration type", "pwa-chrome", fake_dap.configurations.javascript[2].type)
check_true(
  "javascript configuration url",
  fake_dap.configurations.javascript[2].urlFilter:find("17069", 1, true) ~= nil,
  fake_dap.configurations.javascript[2].urlFilter
)

-- Outside Doodba nothing is configured.
vim.cmd("cd /")
vim.cmd("enew")
project.reset()
local before = #fake_dap.configurations.python
check("outside Doodba: no configuration", nil, dap_mod.ensure_configured())
check("outside Doodba: configs unchanged", before, #fake_dap.configurations.python)

vim.fn.delete(base, "rf")

print("")
if failures == 0 then
  print("=== All DAP tests passed ===")
else
  print("=== " .. failures .. " DAP test(s) failed ===")
  os.exit(1)
end
