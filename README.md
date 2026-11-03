# odoo-ide.nvim

> A Neovim plugin for Odoo development: project-aware context detection, LSP integration, smart snippets and Doodba task runners.

## ✨ Features

- **🎯 Context-Aware**: Detects the Odoo version, addon structure and model information from the current buffer
- **🧭 Project Detection**: Works with Doodba environments, local Odoo checkouts and plain addon repositories
- **🔧 odoo-ls Integration**: Starts the official Odoo Language Server with the right `odools.toml`
- **🐳 Doodba Support**: Auto-configuration of addon paths and `odools.toml` for Docker-based environments
- **📝 Smart Snippets**: Version-aware snippets for Python, XML and JavaScript
- **🐞 Debugging**: Optional `nvim-dap` configuration for Odoo containers
- **⚡ Performance**: Cached context detection and configuration files that are only written when they change

## 📋 Requirements

- Neovim **0.10.0+** (0.11.0+ recommended)
- [LuaSnip](https://github.com/L3MON4D3/LuaSnip) for snippets
- [blink.cmp](https://github.com/Saghen/blink.cmp) or [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) for completion
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) and optionally [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) for debugging
- [conform.nvim](https://github.com/stevearc/conform.nvim) and [nvim-lint](https://github.com/mfussenegger/nvim-lint) for the Ruff integration

All of them are optional: the plugin degrades gracefully when one is missing.

## Installation

### Using lazy.nvim

```lua
{
  "antoniodavid/odoo-ide.nvim",
  dependencies = {
    "L3MON4D3/LuaSnip",
  },
  config = function()
    require("odoo-ide").setup({})
  end,
}
```

## Installing odoo-ls (official Odoo Language Server)

The plugin configures `odoo-ls` automatically when the binary is found. Install it manually:

```bash
mkdir -p ~/.local/share/nvim/odoo
cd ~/.local/share/nvim/odoo

# Pick the archive for your platform from
# https://github.com/odoo/odoo-ls/releases/latest
curl -LO https://github.com/odoo/odoo-ls/releases/download/1.6.1/odoo-linux-x86_64-1.6.1.tar.gz
tar -xzf odoo-linux-x86_64-1.6.1.tar.gz   # extracts ./odoo_ls_server
chmod +x odoo_ls_server

# Python typeshed stubs (required for Python builtins)
curl -LO https://github.com/odoo/odoo-ls/releases/download/1.6.1/typeshed.zip
unzip -q typeshed.zip   # extracts stdlib/ and stubs/
```

Supported archive names follow `odoo-<platform>-<arch>-<version>` (linux, darwin, alpine, win32).

### Verify the installation

```bash
~/.local/share/nvim/odoo/odoo_ls_server --version
ls ~/.local/share/nvim/odoo/typeshed/stdlib
```

## Configuration

```lua
require("odoo-ide").setup({
  snippets = {
    enabled = true,
    python = true,
    xml = true,
    js = true,
  },

  lsp = {
    enabled = true,
    pyright = {
      enabled = false, -- odoo-ls is the recommended server for Odoo projects
    },
    odoo_ls = {
      enabled = true,
      auto_config = true,
      profile_name = "main",
      cmd = nil,          -- auto-detected
      stdlib_path = nil,  -- auto-detected
      additional_stubs = {},
      python_path = nil,
    },
  },

  odools = {
    -- nil = project root for Doodba, current working directory for local projects
    output_path = nil,
  },

  ruff = {
    enabled = true,
    format = "ruff_format",
    format_args = {},
    lint = "ruff",
    lint_args = {},
  },

  dap = {
    enabled = true,
    debugpy_port = "auto", -- <ODOO_VERSION>000 + 899, e.g. 17899 for Odoo 17
  },
})
```

## Project detection

The plugin resolves the project that owns the current buffer. Detection is cached
for a few seconds and works from regular files, directory buffers and
`oil.nvim`/`netrw` buffers.

### Doodba

A directory is a Doodba environment when it contains `common.yaml`, or a
`docker-compose.yml` together with an `odoo/custom/src` directory. From there the
plugin:

1. Scans `odoo/custom/src` (including `addons.yaml` entries) for addon paths
2. Injects those paths into `pyright`/`basedpyright` `extraPaths`
3. Generates `odools.toml` for `odoo-ls`
4. Starts `odoo-ls` with the generated configuration

```
project-root/
├── common.yaml
├── docker-compose.yml
├── odools.toml           # generated
└── odoo/
    └── custom/
        └── src/
            ├── odoo/
            ├── enterprise/
            ├── private/
            └── oca-repo/
```

### Local projects (no Doodba)

A local project is detected when, walking upwards from the current buffer:

- a directory contains `odoo-bin` (an Odoo checkout), or
- a directory contains `odoo/release.py` (an Odoo source tree), or
- a `__manifest__.py` is found (a plain addon repository)

The Odoo version comes from `odoo/release.py` (`version_info`), or from
`ODOO_VERSION` in a Doodba `common.yaml`. Extra addon paths are read from
`addons_path` in `odoo.conf` / `.odoorc` (`<root>/odoo.conf`, `<cwd>/odoo.conf`,
`$ODOO_RC`, `~/.odoorc`), so a checkout with a custom addons path works too.

`odoo-ls` starts whenever an Odoo source tree is found. Commands that drive
Docker (`:OdooStart`, `:OdooTest`, `:OdooScaffold`, debugging) still require a
Doodba environment, and say so when they are invoked elsewhere.

A local project does **not** get an `odools.toml` written into the checkout: that
directory is usually a clone of Odoo itself, and dirtying it would be a
nuisance. The language server auto-detects the layout instead. If you want an
explicit configuration, run `:OdooGenerateConfig`: the file is written to the
current working directory (the addon repository you are developing), never to
the core checkout.

## Commands

| Command | Description |
| --- | --- |
| `:OdooHelp` | Quick reference window |
| `:OdooGenerateConfig [all]` | Generate `odools.toml` for the current project |
| `:OdooShowConfig` | Preview the generated `odools.toml` in a buffer |
| `:OdooGeneratePyrightConfig [all]` | Generate `pyrightconfig.json` |
| `:OdooTest [module=x]` | Run the tests of the current module (Doodba) |
| `:OdooInstall [module=x]` | Install the current module (Doodba) |
| `:OdooUninstall [module=x]` | Uninstall the current module (Doodba) |
| `:OdooStart` / `:OdooStop` / `:OdooRestart` | Docker Compose lifecycle (Doodba) |
| `:OdooLogs [tail=N]` | Follow the Odoo container logs (Doodba) |
| `:OdooResetDB [dbname=x modules=y]` | Drop and recreate the development database (Doodba) |
| `:OdooScaffold module_name=x [path=y]` | Scaffold a new module inside the container (Doodba) |
| `:OdooDebug` | Start Odoo with debugpy and attach (Doodba + nvim-dap) |
| `:OdooStartDebug` | Start Odoo with debugpy only (Doodba + nvim-dap) |

Detected context is available programmatically:

```lua
:lua vim.print(require("odoo-ide.context").get_context())
:lua vim.print(require("odoo-ide.project").get())
```

## Snippets

Context-aware snippets that adapt to the Odoo version. A few examples:

| Trigger | Description |
| --- | --- |
| `oocreate` | `create()` method (version-aware) |
| `oowrite` | `write()` method |
| `oomodel` | New model scaffold |
| `oofcompute` | Computed field plus its compute method |
| `oomanifest` | OCA-style `__manifest__.py` |
| `oovtree` | Tree view (uses `list` on Odoo 18+) |
| `oovfull` | Form + tree/list + action + menu |
| `ooowlpatch` | OWL component patch |

Run `:LuaSnipListAvailable` to see every loaded trigger.

## LSP features

With `odoo-ls` installed you get:

- Completion for Odoo models, fields and methods
- Go to definition for model references
- Hover documentation
- Diagnostics for common Odoo issues
- XML view validation

## Tests

The test suite runs in headless Neovim with temporary fixtures and needs no Odoo
checkout:

```bash
make test
```

Individual suites:

```bash
nvim --headless -u NONE -l tests/test_project.lua
nvim --headless -u NONE -l tests/test_context.lua
nvim --headless -u NONE -l tests/test_odools_config.lua
nvim --headless -u NONE -l tests/test_doodba_root.lua
nvim --headless -u NONE -l tests/test_scaffold_path.lua
nvim --headless -u NONE -l tests/test_nvim.lua
```

## Troubleshooting

### odoo-ls not starting

1. Check that the binary is executable:

   ```bash
   ls -la ~/.local/share/nvim/odoo/odoo_ls_server
   ```

2. Check that typeshed is installed:

   ```bash
   ls ~/.local/share/nvim/odoo/typeshed/stdlib
   ```

3. Check the attached clients with `:checkhealth vim.lsp`, and the generated
   configuration with `:OdooShowConfig`.

### Snippets not appearing

1. Ensure your completion engine uses the LuaSnip preset (for blink.cmp:
   `snippets = { preset = "luasnip" }`)
2. Check `:LuaSnipListAvailable`

### Paths not detected

Run `:lua vim.print(require("odoo-ide.project").get())` and
`:lua vim.print(require("odoo-ide.context").get_context())` to inspect what the
plugin sees.

## License

MIT
