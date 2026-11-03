
-- verify_lsp.lua
local target_file = "/home/adruban/Workspace/Doodba_ENV/O17/odoo/custom/src/amp/cgcof_contact_fields/models/res_partner.py"

-- Open the file
vim.cmd("edit " .. target_file)

-- Wait for LSPs to start (they are async)
print("Waiting for LSPs to attach...")

-- We use a timer to check periodically
local timer = vim.loop.new_timer()
local count = 0
timer:start(1000, 1000, function()
  count = count + 1
  local clients = vim.lsp.get_clients({ bufnr = vim.fn.bufnr(target_file) })
  
  if #clients >= 2 or count > 10 then
    timer:stop()
    timer:close()
    
    print("Found " .. #clients .. " clients:")
    for _, client in ipairs(clients) do
      print("- " .. client.name .. " (root: " .. (client.config.root_dir or "nil") .. ")")
      if (client.name == "pyright" or client.name == "basedpyright") and client.config.settings and client.config.settings.python then
         local paths = client.config.settings.python.analysis.extraPaths
         print("  ExtraPaths count: " .. (paths and #paths or 0))
         -- print("  ExtraPaths: " .. vim.inspect(paths)) 
      end
    end
    
    if #clients < 2 then
        print("FAILURE: Expected at least 2 clients (odoo_ls and pyright/basedpyright)")
        os.exit(1)
    else
        print("SUCCESS: Both clients attached")
        os.exit(0)
    end
  end
end)
