-- Portable regression tests for project detection.
--
-- Covers Doodba environments, local Odoo checkouts, plain addons
-- repositories, odoo.conf addons paths and non-project directories.
--
-- Run with: nvim --headless -u NONE -l tests/test_project.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

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

local function edit(path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  project.reset()
end

local base = vim.fn.fnamemodify(vim.fn.tempname(), ":p:h") .. "/odoo-ide-project-test"
vim.fn.delete(base, "rf")

-- Isolate the machine: global Odoo configuration (odoo.conf / ~/.odoorc) must
-- not leak into the fixtures.
local original_home = vim.env.HOME
local original_rc = vim.env.ODOO_RC
vim.env.HOME = base .. "/home"
vim.env.ODOO_RC = ""
vim.fn.mkdir(vim.env.HOME, "p")

-- A global config whose addons_path belongs to a different Odoo installation.
local global_addons = base .. "/global_addons"
vim.fn.mkdir(global_addons, "p")
write_file(vim.env.HOME .. "/.odoorc", "addons_path = " .. global_addons .. "\n")

-- Doodba environment.
local doodba_root = base .. "/doodba"
write_file(doodba_root .. "/common.yaml", 'version: "2.4"\n\nservices:\n  odoo:\n    build:\n      args:\n        ODOO_VERSION: "17.0"\n')
write_file(doodba_root .. "/odoo/custom/src/odoo/odoo-bin", "\n")
vim.fn.mkdir(doodba_root .. "/odoo/custom/src/odoo/addons", "p")
write_file(doodba_root .. "/odoo/custom/src/private/test_addon/__manifest__.py", "{'name': 'test_addon'}\n")
write_file(doodba_root .. "/odoo/custom/src/private/test_addon/models/test.py", "from odoo import models\n")

edit(doodba_root .. "/odoo/custom/src/private/test_addon/models/test.py")
local doodba_project = project.get()
check_true("doodba: detected", doodba_project ~= nil)
check("doodba: kind", "doodba", doodba_project and doodba_project.kind)
check("doodba: root", doodba_root, doodba_project and doodba_project.root)
check(
  "doodba: odoo path",
  doodba_root .. "/odoo/custom/src/odoo",
  doodba_project and doodba_project.odoo_path
)
check("doodba: version from common.yaml", 17, doodba_project and doodba_project.version)
check_true(
  "doodba: private addons path",
  doodba_project ~= nil
    and vim.tbl_contains(doodba_project.addons_paths, doodba_root .. "/odoo/custom/src/private")
)
check_true(
  "doodba: global rc is ignored",
  doodba_project ~= nil and not vim.tbl_contains(doodba_project.addons_paths, global_addons)
)
check_true("doodba: is_doodba", project.is_doodba(doodba_project))

-- Local Odoo checkout.
local checkout = base .. "/checkout"
write_file(checkout .. "/odoo-bin", "#!/usr/bin/env python3\n")
write_file(checkout .. "/odoo/release.py", "version_info = (18, 0, 0, 'final', 0, '', 0)\n")
vim.fn.mkdir(checkout .. "/addons", "p")
vim.fn.mkdir(checkout .. "/odoo/addons", "p")
write_file(checkout .. "/my_module/__manifest__.py", "{'name': 'my_module'}\n")
write_file(checkout .. "/my_module/models/my_model.py", "from odoo import models\n")

edit(checkout .. "/my_module/models/my_model.py")
local local_project = project.get()
check_true("local: detected", local_project ~= nil)
check("local: kind", "local", local_project and local_project.kind)
check("local: root", checkout, local_project and local_project.root)
check("local: odoo path", checkout, local_project and local_project.odoo_path)
check("local: version from release.py", 18, local_project and local_project.version)
check_true(
  "local: addons path",
  local_project ~= nil and vim.tbl_contains(local_project.addons_paths, checkout .. "/addons")
)
check_true(
  "local: core addons path",
  local_project ~= nil and vim.tbl_contains(local_project.addons_paths, checkout .. "/odoo/addons")
)
check_true(
  "local: global rc is ignored",
  local_project ~= nil and not vim.tbl_contains(local_project.addons_paths, global_addons)
)
check_true("local: not doodba", not project.is_doodba(local_project))

-- Plain addons repository (no Odoo core) plus an odoo.conf addons_path.
local repo = base .. "/addons-repo"
write_file(repo .. "/addon_a/__manifest__.py", "{'name': 'addon_a'}\n")
write_file(repo .. "/addon_b/__manifest__.py", "{'name': 'addon_b'}\n")
vim.fn.mkdir(repo .. "/extra_addons", "p")
write_file(repo .. "/odoo.conf", "addons_path = ./extra_addons,/does/not/exist\n")

edit(repo .. "/addon_a/__manifest__.py")
local repo_project = project.get()
check_true("repo: detected", repo_project ~= nil)
check("repo: kind", "local", repo_project and repo_project.kind)
check("repo: root", repo, repo_project and repo_project.root)
check("repo: no odoo path", nil, repo_project and repo_project.odoo_path)
check("repo: version unknown", nil, repo_project and repo_project.version)
check_true(
  "repo: repository itself is an addons path",
  repo_project ~= nil and vim.tbl_contains(repo_project.addons_paths, repo)
)
check_true(
  "repo: odoo.conf relative addons path",
  repo_project ~= nil and vim.tbl_contains(repo_project.addons_paths, repo .. "/extra_addons")
)
check_true(
  "repo: missing conf path ignored",
  repo_project ~= nil and not vim.tbl_contains(repo_project.addons_paths, "/does/not/exist")
)
check_true(
  "repo: global rc is used as fallback",
  repo_project ~= nil and vim.tbl_contains(repo_project.addons_paths, global_addons)
)

-- A docker-compose.yml alone must not be treated as a Doodba environment.
local compose_only = base .. "/compose-only"
write_file(compose_only .. "/docker-compose.yml", "services:\n  web:\n    image: nginx\n")
write_file(compose_only .. "/main.py", "print('hello')\n")

edit(compose_only .. "/main.py")
check("compose only: no project", nil, project.get())

-- A Doodba environment may be recognised from the compose file when the
-- source layout exists too.
local compose_doodba = base .. "/compose-doodba"
write_file(compose_doodba .. "/docker-compose.yml", "services: {}\n")
write_file(compose_doodba .. "/odoo/custom/src/odoo/odoo-bin", "\n")
write_file(compose_doodba .. "/odoo/custom/src/private/mod/__manifest__.py", "{'name': 'mod'}\n")
write_file(compose_doodba .. "/odoo/custom/src/private/mod/models/m.py", "from odoo import models\n")

edit(compose_doodba .. "/odoo/custom/src/private/mod/models/m.py")
local compose_project = project.get()
check("compose doodba: kind", "doodba", compose_project and compose_project.kind)
check("compose doodba: root", compose_doodba, compose_project and compose_project.root)

-- Nothing Odoo related at all.
vim.cmd("cd /")
vim.cmd("enew")
project.reset()
check("outside: no project", nil, project.get())

vim.fn.delete(base, "rf")
vim.env.HOME = original_home
vim.env.ODOO_RC = original_rc or ""

print("")
if failures == 0 then
  print("=== All project tests passed ===")
else
  print("=== " .. failures .. " project test(s) failed ===")
  os.exit(1)
end
