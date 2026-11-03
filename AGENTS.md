# AGENTS.md

This file contains instructions, conventions, and operational guidelines for agentic coding assistants working in the `odoo-ide.nvim` repository.

## 1. Project Context
- **Name**: `odoo-ide.nvim`
- **Type**: Neovim plugin.
- **Purpose**: A Neovim plugin that provides intelligent context detection, LSP integration (`odoo-ls`, `pyright`, `ruff`), Docker/Doodba container support, and smart snippets for Odoo development.
- **Primary Language**: Lua (LuaJIT compatible, Neovim 0.9.0+ API).

## 2. Build, Lint, and Test Commands

Since this is a Neovim plugin written in Lua, there is no separate compilation step. The code runs directly within Neovim.

### Testing
Tests are custom Lua scripts run via headless Neovim to simulate the Neovim environment and mock `vim` APIs when needed.

**Run a single test file:**
```bash
nvim --headless -u NONE -c "lua dofile('tests/<test_file>.lua')" +q
```
*Example:*
```bash
nvim --headless -u NONE -c "lua dofile('tests/test_context.lua')" +q
```

**Testing Guidelines:**
- The plugin does **not** currently use `plenary.busted` for tests. Tests are standalone scripts.
- To execute and verify functionality, you may need to mock `vim.fn` or other `vim` globals within the test file if they aren't available in headless mode. (See `tests/test_context.lua` for mock examples).
- For quick script evaluation in development, you can use standard `lua <script>.lua`, but only if the script does not strictly depend on `vim` APIs or successfully mocks them.

### Linting & Formatting
- **Formatter**: There is no `.stylua.toml` present, but strictly enforce a **2-space indentation** for all Lua files.
- **Linter**: There is no explicit `luacheck` or `selene` config. Rely on strict Lua syntax and accurate EmmyLua type annotations to maintain code quality.

## 3. Code Style & Architectural Guidelines

### File Structure & Imports
- **Modules**: Every module should return a table. Use the standard Neovim Lua module pattern:
  ```lua
  local M = {}
  -- module logic
  return M
  ```
- **Requires**: Use absolute-style require paths internal to the plugin: `require("odoo-ide.<module>")`.
- **Lazy Loading/Safety**: Use `pcall` heavily when loading optional dependencies or external plugins to prevent the entire plugin from crashing if a user lacks a dependency.
  ```lua
  local ok, dap = pcall(require, "odoo-ide.dap")
  if ok then
    dap.setup()
  end
  ```

### Typing and Documentation
- Use **EmmyLua annotations** for all public API functions and complex tables. This enables LSP autocompletion and serves as inline documentation.
  ```lua
  ---Detect Odoo version from __manifest__.py
  ---@param path string The path to the manifest file
  ---@return number|nil version The detected Odoo version
  function M.get_version(path)
    -- ...
  end
  ```

### Naming Conventions
- **Variables & Functions**: Use `snake_case` for all variables and function names (`local my_var = 1`, `function M.get_context()`).
- **Constants**: Use `UPPER_SNAKE_CASE` for global-level constants.
- **File Names**: Use `snake_case.lua` (e.g., `test_real_project.lua`).

### Error Handling & Logging
- **Notifications**: Use `vim.notify` for user-facing warnings or errors, rather than `print()`.
  ```lua
  vim.notify("odoo-ide: LuaSnip not available, snippets disabled", vim.log.levels.WARN)
  ```
- **Failsafes**: Always check for `nil` returns. For example, if a file or directory isn't found during context detection, return gracefully without throwing a hard Lua error.

### Neovim API Usage
- Prefer modern `vim.*` APIs over legacy `vim.cmd` or `vim.fn` where possible.
  - File system operations: Use `vim.fs` (e.g., `vim.fs.find`, `vim.fs.dirname`) or `vim.uv` (libuv bindings) instead of `vim.fn.findfile`.
  - Buffer operations: `vim.api.nvim_buf_get_lines`, `vim.api.nvim_buf_set_extmark`, etc.
  - Scheduling: Use `vim.schedule(function() ... end)` if manipulating the UI from asynchronous libuv callbacks.

## 4. Feature Implementation Rules
- **Context Detection**: The plugin heavily relies on traversing up the filesystem tree to find `__manifest__.py` to detect an Odoo context. Avoid hardcoded paths; use dynamic resolution based on the current buffer (`%:p:h`).
- **Doodba Support**: When interacting with the environment, account for standard Doodba structures (`common.yaml`, `odoo/custom/src`).
- **Snippets**: Snippets rely on `LuaSnip`. Only initialize snippet structures if the `LuaSnip` requirement passes via `pcall`.

## 5. Security & Safety Rules
- **No destructive actions**: Do not run commands that delete or aggressively modify user code without explicit instruction.
- **Subprocesses**: When spawning processes (like starting an LSP server or executing Doodba commands), use non-blocking APIs like `vim.system` (Neovim 0.10+) or `vim.loop.spawn` to prevent freezing the main UI thread.
