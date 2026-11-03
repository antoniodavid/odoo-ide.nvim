local doodba = require("odoo-ide.doodba")
local odools = require("odoo-ide.odools")

print("Doodba Root: " .. (doodba.find_root() or "nil"))

local config, err = odools.generate_config({
  include_all_repos = true,
  profile_name = "test_profile"
})

if config then
  print("\nGenerated Config:")
  print(config)
else
  print("\nError: " .. (err or "Unknown"))
end
