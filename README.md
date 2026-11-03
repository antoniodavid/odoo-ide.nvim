# odoo-ide.nvim

> A comprehensive Neovim plugin for Odoo development with intelligent context detection, LSP integration, and smart snippets.

## ✨ Features

- **🎯 Context-Aware**: Automatically detects Odoo version, addon structure, and model information
- **🔧 Official LSP Integration**: Seamless integration with `odoo-ls` (official Odoo Language Server)
- **🐳 Doodba Support**: Auto-configuration for Docker-based Doodba environments
- **📝 Smart Snippets**: Version-aware, OCA-compliant snippets for Odoo 16-20
- **🔍 Pyright Integration**: Automatic `extraPaths` configuration for basedpyright/pyright
- **⚡ Performance**: Intelligent caching for fast context detection

## 📋 Requirements

- Neovim 0.9.0+ (0.11.0+ recommended)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [LuaSnip](https://github.com/L3MON4D3/LuaSnip) (for snippets)
- [blink.cmp](https://github.com/Saghen/blink.cmp) or [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)

## Installation

### Using lazy.nvim

```lua
{
  "antoniodavid/odoo-ide.nvim",
  dependencies = {
    "neovim/nvim-lspconfig",
    "L3MON4D3/LuaSnip",
  },
  config = function()
    require("odoo-ide").setup({})
  end,
}
```

### Installing odoo-ls (Official Odoo Language Server)

The plugin automatically configures `odoo-ls` if the binary is found. You need to install it manually:

#### 1. Download the binary

```bash
mkdir -p ~/.local/share/nvim/odoo
wget -O ~/.local/share/nvim/odoo/odoo_ls_server \
  https://github.com/odoo/odoo-ls/releases/latest/download/odoo_ls_server-linux-x64
chmod +x ~/.local/share/nvim/odoo/odoo_ls_server
```

#### 2. Download Python typeshed (required for Python builtins)

```bash
git clone --depth 1 https://github.com/python/typeshed.git \
  ~/.local/share/nvim/odoo/typeshed
```

#### 3. Verify installation

```bash
~/.local/share/nvim/odoo/odoo_ls_server --version
```

## Configuration

```lua
require("odoo-ide").setup({
  doodba_aware = true,

  snippets = {
    enabled = true,
    python = true,
    xml = true,
    js = true,
  },

  lsp = {
    enabled = true,
    auto_configure = true,

    pyright = {
      enabled = true,
    },

    odoo_ls = {
      enabled = true,
      auto_config = true,
      profile_name = "main",
      cmd = nil,
      stdlib_path = nil,
      additional_stubs = {},
      python_path = nil,
    },
  },

  odools = {
    auto_generate = true,
    force_regenerate = false,
    output_path = nil,
  },
})
```

## Doodba Integration

When working in a Doodba project (detected by `common.yaml` or `docker-compose.yml`), the plugin automatically:

1. Scans `odoo/custom/src` for all addon paths
2. Injects paths into pyright/basedpyright `extraPaths`
3. Generates `odools.toml` configuration for `odoo-ls`
4. Configures `odoo-ls` with correct paths

Detection starts from the current buffer directory and also works on directory
buffers such as oil.nvim (`oil://...`), so starting Neovim on a project folder
(e.g. `nvim .`) still finds the Doodba root.

### Expected Doodba Structure

```
project-root/
├── common.yaml           # Doodba marker
├── docker-compose.yml
├── odools.toml           # Auto-generated
└── odoo/
    └── custom/
        └── src/
            ├── odoo/           # Odoo core
            │   ├── odoo/
            │   └── addons/
            ├── enterprise/     # Enterprise addons
            ├── private/        # Private addons
            └── oca-repo/       # OCA repositories
```

## Commands

| Command                                             | Description                 |
| --------------------------------------------------- | --------------------------- |
| `:lua require("odoo-ide").debug()`                  | Show detected context       |
| `:lua require("odoo-ide").generate_odools_config()` | Regenerate odools.toml      |
| `:lua require("odoo-ide").show_odools_config()`     | Preview odools.toml content |

## Snippets

Context-aware snippets that adapt to Odoo version:

| Trigger    | Description                          |
| ---------- | ------------------------------------ |
| `oocreate` | `create()` method (version-aware)    |
| `oowrite`  | `write()` method (version-aware)     |
| `oovtree`  | Tree view (adapts to 18+ owl syntax) |
| `oovform`  | Form view                            |
| `oomodel`  | New model scaffold                   |

## LSP Features

With `odoo-ls` installed, you get:

- Autocompletion for Odoo models, fields, and methods
- Go to definition for model references
- Hover documentation
- Diagnostics for common Odoo issues
- XML view validation

## Troubleshooting

### odoo-ls not starting

1. Check if binary is executable:

   ```bash
   ls -la ~/.local/share/nvim/odoo/odoo_ls_server
   ```

2. Check if typeshed is installed:

   ```bash
   ls ~/.local/share/nvim/odoo/typeshed/stdlib
   ```

3. Check `:LspInfo` in Neovim to see if odoo_ls is configured

### Snippets not appearing

1. Ensure blink.cmp has luasnip preset:

   ```lua
   snippets = { preset = "luasnip" }
   ```

2. Check `:LuaSnipListAvailable` for loaded snippets

### Paths not detected

Run `:lua require("odoo-ide").debug()` to see detected context and paths.

## License

MIT
