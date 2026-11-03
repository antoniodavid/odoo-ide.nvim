
if not vim then
  vim = {
    fn = {
      filereadable = function(path) 
        local f = io.open(path, "r")
        if f then f:close() return 1 end
        return 0
      end,
      isdirectory = function(path)
        local ok, err, code = os.rename(path, path)
        if ok or code == 13 then return 1 end
        return 0
      end,
      readfile = function(path)
        local lines = {}
        for line in io.lines(path) do
          table.insert(lines, line)
        end
        return lines
      end,
      expand = function(s) return s:gsub("%%:p:h", os.getenv("PWD") or ".") end,
      getcwd = function() return os.getenv("PWD") or "." end,
    },
    fs = {
      find = function(name, opts)
        local path = opts.path
        if path then
          local check = path .. "/" .. name
          local f = io.open(check, "r")
          if f then f:close() return {check} end
        end
        return {}
      end,
      dirname = function(p) return p:match("(.*/)[^/]*$"):sub(1,-2) end,
    },
    loop = {
      fs_scandir = function(path)
        local handle = io.popen('ls -1 "' .. path .. '" 2>/dev/null')
        if not handle then return nil end
        local entries = {}
        for line in handle:lines() do
          table.insert(entries, line)
        end
        handle:close()
        entries.idx = 1
        entries.path = path
        return entries
      end,
      fs_scandir_next = function(handle)
        if not handle or handle.idx > #handle then return nil end
        local name = handle[handle.idx]
        handle.idx = handle.idx + 1
        local path = handle.path .. "/" .. name
        local attr = io.popen('test -d "' .. path .. '" && echo dir || echo file')
        local type = attr:read("*l")
        attr:close()
        return name, type == "dir" and "directory" or "file"
      end,
    },
    json = {
      encode = function(t) 
        local function serialize(o, indent)
          indent = indent or 0
          local spaces = string.rep("  ", indent)
          if type(o) == "number" then
            return tostring(o)
          elseif type(o) == "boolean" then
            return tostring(o)
          elseif type(o) == "string" then
            return string.format("%q", o)
          elseif type(o) == "table" then
            local is_array = #o > 0
            if is_array then
              local items = {}
              for _, v in ipairs(o) do
                table.insert(items, serialize(v, indent + 1))
              end
              return "[" .. table.concat(items, ", ") .. "]"
            else
              local items = {}
              for k, v in pairs(o) do
                table.insert(items, spaces .. "  " .. string.format("%q", k) .. ": " .. serialize(v, indent + 1))
              end
              return "{\n" .. table.concat(items, ",\n") .. "\n" .. spaces .. "}"
            end
          end
          return "null"
        end
        return serialize(t)
      end
    },
    notify = function(msg) print("Notify:", msg) end,
    log = { levels = { INFO = 1, ERROR = 2 } },
    api = { nvim_create_user_command = function() end }
  }
end

package.path = package.path .. ";./lua/?.lua"

local test_root = "/home/adruban/Workspace/Doodba_ENV/O17"

local orig_find = vim.fs.find
vim.fs.find = function(name, opts)
  if name == "common.yaml" then
    local f = io.open(test_root .. "/common.yaml", "r")
    if f then f:close() return {test_root .. "/common.yaml"} end
  end
  return orig_find(name, opts)
end

vim.fn.getcwd = function() return test_root end
vim.fn.expand = function(s)
  if s == "%:p:h" then return test_root .. "/odoo/custom/src/private" end
  return s
end

local doodba = require("odoo-ide.doodba")
local odools = require("odoo-ide.odools")

print("=== Testing with real O17 project ===")
print("Root:", doodba.find_root())

local content, err = odools.generate_config({})
if err then
  print("ERROR:", err)
else
  print("Generated config:")
  print(content)
  print("")
  if content:match("^%./") or content:match('"%.%/') then
    print("PASS: Relative paths detected")
  else
    print("FAIL: No relative paths found")
  end
  if content:match("//") then
    print("FAIL: Double slashes detected!")
  else
    print("PASS: No double slashes")
  end
end
