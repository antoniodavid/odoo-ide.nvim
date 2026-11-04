-- Portable tests for the Ruff integration helpers.
--
-- Run with: nvim --headless -u NONE -l tests/test_ruff.lua

local script = debug.getinfo(1, "S").source:sub(2)
local plugin_root = vim.fn.fnamemodify(script, ":p:h:h")
vim.opt.rtp:prepend(plugin_root)

local ruff = require("odoo-ide.ruff")

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

-- Arguments: the stdin marker must be the last one.
local args = ruff.build_args({})
check("args: count", 5, #args)
check("args: subcommand", "check", args[1])
check("args: json output", "--output-format=json", args[2])
check("args: stdin filename", "--stdin-filename", args[3])
check("args: placeholder", "%:p", args[4])
check("args: stdin marker last", "-", args[#args])

local with_extras = ruff.build_args({ lint_args = { "--select", "E,F" } })
check("extra args: count", 7, #with_extras)
check("extra args: first extra", "--select", with_extras[5])
check("extra args: second extra", "E,F", with_extras[6])
check("extra args: stdin marker still last", "-", with_extras[#with_extras])

-- Severity mapping by rule code.
check("severity: pyflakes error", vim.diagnostic.severity.ERROR, ruff.severity("F401"))
check("severity: pycodestyle error", vim.diagnostic.severity.ERROR, ruff.severity("E501"))
check("severity: warning", vim.diagnostic.severity.WARN, ruff.severity("W291"))
check("severity: isort", vim.diagnostic.severity.WARN, ruff.severity("I001"))
check("severity: unknown code", vim.diagnostic.severity.WARN, ruff.severity(nil))

-- JSON parsing.
local output = vim.json.encode({
  {
    code = "F401",
    message = "'os' imported but unused",
    location = { row = 3, column = 8 },
    end_location = { row = 3, column = 10 },
    fix = { applicability = "safe" },
  },
  {
    code = "W291",
    message = "Trailing whitespace",
    location = { row = 10, column = 1 },
  },
})

local diagnostics = ruff.parse(output)
check("parse: count", 2, #diagnostics)
check("parse: lnum is zero based", 2, diagnostics[1].lnum)
check("parse: col is zero based", 7, diagnostics[1].col)
check("parse: end lnum", 2, diagnostics[1].end_lnum)
check("parse: end col", 9, diagnostics[1].end_col)
check("parse: message", "'os' imported but unused", diagnostics[1].message)
check("parse: source", "ruff", diagnostics[1].source)
check("parse: code", "F401", diagnostics[1].code)
check("parse: error severity", vim.diagnostic.severity.ERROR, diagnostics[1].severity)
check("parse: missing end_location falls back", 9, diagnostics[2].end_lnum)
check("parse: warning severity", vim.diagnostic.severity.WARN, diagnostics[2].severity)

-- Malformed output never throws.
local broken = ruff.parse("not json")
check("parse: invalid output", 0, #broken)
check("parse: empty output", 0, #ruff.parse(""))

-- List form.
local list = ruff.append_name({ "stylua" }, "ruff_format")
check("append: list keeps existing", "stylua", list[1])
check("append: list appends", "ruff_format", list[2])
check("append: list count", 2, #list)

local deduped = ruff.append_name({ "ruff_format" }, "ruff_format")
check("append: list deduplicates", 1, #deduped)

local created = ruff.append_name(nil, "ruff")
check("append: creates table", "ruff", created[1])

-- Function form: the wrapper must call the original and append once.
local calls = 0
local function_form = ruff.append_name(function()
  calls = calls + 1
  return { "mypy" }
end, "ruff")

local first = function_form(1)
check("append: function keeps original", "mypy", first[1])
check("append: function appends", "ruff", first[2])
check("append: function callback used", 1, calls)

local second = function_form(1)
check("append: function does not duplicate", 2, #second)

print("")
if failures == 0 then
  print("=== All Ruff tests passed ===")
else
  print("=== " .. failures .. " Ruff test(s) failed ===")
  os.exit(1)
end
