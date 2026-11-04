-- Portable tests for the scaffold path mapping.
--
-- The project root is mounted at /tmp/project inside the container, so host
-- paths must be rewritten to container paths before calling `odoo scaffold`.
--
-- Run with: nvim --headless -u NONE -l tests/test_scaffold_path.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local tasks = require("odoo-ide.tasks")

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

local root = "/tmp/odoo-ide-scaffold/env"

check(
  "absolute path under the root",
  "/tmp/project/odoo/custom/src/private",
  (tasks.container_path(root, root .. "/odoo/custom/src/private"))
)

check(
  "project-relative path",
  "/tmp/project/odoo/custom/src/private",
  (tasks.container_path(root, "odoo/custom/src/private"))
)

check("dot-relative path", "/tmp/project/my_module", (tasks.container_path(root, "./my_module")))

check(
  "root with trailing slash",
  "/tmp/project/odoo/custom/src/private",
  (tasks.container_path(root .. "/", root .. "/odoo/custom/src/private"))
)

local outside, err = tasks.container_path(root, "/home/someone/other_project/module")
check("absolute path outside the root", nil, outside)
check_true("outside path reports an error", type(err) == "string" and err:find("outside the project root") ~= nil, err)

check("missing target", nil, (tasks.container_path(root, nil)))
check("missing root", nil, (tasks.container_path(nil, "module")))

-- Docker service and database names are configurable.
tasks.setup({ tasks = { dbname = "custom_db", service = "web", proxy_service = "proxy" } })
check("tasks: dbname override", "custom_db", tasks.options.dbname)
check("tasks: service override", "web", tasks.options.service)
check("tasks: proxy service override", "proxy", tasks.options.proxy_service)

tasks.setup({})
check("tasks: default dbname", "devel", tasks.options.dbname)
check("tasks: default service", "odoo", tasks.options.service)
check("tasks: default proxy service", "odoo_proxy", tasks.options.proxy_service)

print("")
if failures == 0 then
  print("=== All scaffold path tests passed ===")
else
  print("=== " .. failures .. " scaffold path test(s) failed ===")
  os.exit(1)
end
