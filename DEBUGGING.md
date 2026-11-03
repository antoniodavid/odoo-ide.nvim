# Debugging Odoo in Neovim

This guide explains how to debug Odoo projects running in **Doodba** containers using `odoo-ide.nvim` and `nvim-dap`.

## Prerequisites

1.  **Plugins Installed**:
    *   `mfussenegger/nvim-dap`
    *   `rcarriga/nvim-dap-ui` (Recommended)
    *   `mfussenegger/nvim-dap-python` (Optional, but useful)

2.  **Doodba Environment**:
    *   Your project must be a Doodba-based setup (detected by `common.yaml`).

## Step 1: Start Odoo in Debug Mode

To attach the debugger, the Odoo server must be running with `debugpy` (formerly ptvsd) enabled. In Doodba, this is done via the `invoke` command.

Open your terminal in the project root and run:

```bash
invoke start --detach --debugpy
# OR
invoke start -d --debugpy
```

This will:
*   Start the Odoo container.
*   Enable the debugpy listener on a specific port.
    *   **Port Calculation**: `(ODOO_VERSION * 1000) + 899`
    *   *Example (Odoo 17):* Port `17899`
    *   *Example (Odoo 16):* Port `16899`

## Step 2: Open a Python File in Neovim

Navigate to any Odoo Python file in your project:

```bash
nvim odoo/custom/src/my_module/models/my_model.py
```

## Step 3: Start Debugging

1.  Set a breakpoint on a line you want to inspect:
    *   Command: `:DapToggleBreakpoint`
    *   *(Tip: Map this to `<Leader>db` or `<F9>`)*

2.  Start the debugger:
    *   Command: `:DapContinue`
    *   *(Tip: Map this to `<Leader>dc` or `<F5>`)*

3.  Select the Configuration:
    *   You will see a list of configurations. Select:
        > **Odoo: Attach to Container (Port XXXXX)**

4.  Trigger the code path in Odoo (e.g., click the button in the UI).
5.  Neovim will pause at the breakpoint.

## Troubleshooting

### "Connection Refused"
*   Ensure Odoo was started with `--debugpy`.
*   Check if the port is correct. Run `docker ps` and look for the port mapping on the `odoo` container.

### Breakpoints not hitting
*   **Path Mappings**: Docker debugging relies on mapping local files to remote files. `odoo-ide.nvim` auto-generates these mapping for:
    *   `odoo/custom/src/odoo` -> `/opt/odoo/custom/src/odoo`
    *   `odoo/custom/src/private` -> `/opt/odoo/custom/src/private`
    *   `odoo/custom/src/<repo>/<addon>` -> `/opt/odoo/auto/addons/<addon>`
*   If your addon is in a non-standard location, the mapping might be missing. Check `:lua require("odoo-ide").debug()` (future feature) or inspect `dap.configurations.python` manually.

## JavaScript Debugging (Experimental)

To debug Owl/JS components:

1.  Ensure you have a standard Chrome instance running with remote debugging enabled (port 9222).
2.  Select **"Odoo: Attach Chrome (Port 9222)"** in DAP.
3.  *Note:* JS debugging often requires complex source-map setups. This feature is currently basic.
