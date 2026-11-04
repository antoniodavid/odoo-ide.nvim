-- Portable tests for the odoo-ls command line and LSP capabilities.
--
-- Run with: nvim --headless -u NONE -l tests/test_lsp_cmd.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local lsp = require("odoo-ide.lsp")

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

local binary = "/opt/odoo/odoo_ls_server"

local minimal = lsp.build_odoo_ls_cmd(binary, {}, nil, nil)
check("minimal: binary first", binary, minimal[1])
check("minimal: profile flag", "--selected-config", minimal[2])
check("minimal: default profile", "main", minimal[3])
check("minimal: length", 3, #minimal)

local full = lsp.build_odoo_ls_cmd(
  binary,
  { profile_name = "custom" },
  "/project/odools.toml",
  "/opt/typeshed/stdlib"
)
check("full: length", 7, #full)
check("full: config flag", "--config-path", full[2])
check("full: config path", "/project/odools.toml", full[3])
check("full: stdlib flag", "--stdlib", full[4])
check("full: stdlib path", "/opt/typeshed/stdlib", full[5])
check("full: profile flag", "--selected-config", full[6])
check("full: profile name", "custom", full[7])

local no_profile = lsp.build_odoo_ls_cmd(binary, { profile_name = nil }, nil, nil)
check("nil profile falls back to main", "main", no_profile[3])

-- Capabilities: defaults are preserved and user values are merged in.
local defaults = lsp.capabilities(nil)
check_true("capabilities: defaults present", type(defaults.workspace) == "table")
check_true("capabilities: completion present", type(defaults.textDocument.completion) == "table")

local merged = lsp.capabilities({
  textDocument = {
    hover = { contentFormat = { "markdown" } },
    completion = { completionItem = { snippetSupport = true } },
  },
  experimental = { odooIde = true },
})
check_true("capabilities: user value merged", merged.textDocument.hover.contentFormat[1] == "markdown")
check_true("capabilities: nested user value merged", merged.textDocument.completion.completionItem.snippetSupport == true)
check_true("capabilities: unrelated user key merged", merged.experimental.odooIde == true)
check_true("capabilities: defaults kept after merge", merged.workspace.applyEdit == true)

-- Merging must not mutate the table returned by the protocol module.
local again = lsp.capabilities(nil)
check_true("capabilities: no global mutation", again.experimental == nil)

print("")
if failures == 0 then
  print("=== All LSP command tests passed ===")
else
  print("=== " .. failures .. " LSP command test(s) failed ===")
  os.exit(1)
end
