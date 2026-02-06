# viml-surround

A lightweight surround plugin for Neovim, written in Lua. Add, delete, and
change surrounding pairs with minimal keystrokes.

## Requirements

- Neovim >= 0.7

## Installation

### lazy.nvim

```lua
{ "4ree/viml-surround" }
```

### packer.nvim

```lua
use "4ree/viml-surround"
```

### Manual

Clone into your Neovim packages directory:

```sh
git clone https://github.com/4ree/viml-surround \
  ~/.local/share/nvim/site/pack/plugins/start/viml-surround
```

## Usage

### `ys{motion}{char}` — add surround

Surround the text covered by any motion or text object.

| Keystrokes | Before | After |
|------------|--------|-------|
| `ysiw(` | `hello` | `(hello)` |
| `ysiw)` | `hello` | `( hello )` |
| `ys$"` | `hello world` | `"hello world"` |
| `ysiwt` + `div` | `hello` | `<div>hello</div>` |

### `yss{char}` — surround entire line

| Keystrokes | Before | After |
|------------|--------|-------|
| `yss(` | `hello world` | `(hello world)` |

### `ds{char}` — delete surround

| Keystrokes | Before | After |
|------------|--------|-------|
| `ds(` | `(hello)` | `hello` |
| `ds"` | `"hello"` | `hello` |
| `dst` | `<div>hello</div>` | `hello` |

### `gs{char}` — visual surround

Select text in visual mode, then press `gs` followed by the surround character.

| Keystrokes | Selection | After |
|------------|-----------|-------|
| `viw`, `gs(` | `hello` | `(hello)` |
| `V`, `gs{` | `hello world` | `{` on line above, `}` on line below |

## Surround pairs

| Char | Open | Close | Notes |
|------|------|-------|-------|
| `(` | `(` | `)` | tight |
| `)` | `( ` | ` )` | spaced |
| `[` | `[` | `]` | tight |
| `]` | `[ ` | ` ]` | spaced |
| `{` | `{` | `}` | tight |
| `}` | `{ ` | ` }` | spaced |
| `<` | `<` | `>` | tight |
| `>` | `< ` | ` >` | spaced |
| `'` | `'` | `'` | |
| `"` | `"` | `"` | |
| `` ` `` | `` ` `` | `` ` `` | |
| `t` | `<tag>` | `</tag>` | prompts for tag name |

Any other character uses itself as both the opening and closing delimiter
(e.g., `ds/` deletes surrounding `/`).

## Custom keymaps

Set `vim.g.loaded_surround = true` before the plugin loads to disable
default mappings, then define your own:

```lua
vim.g.loaded_surround = true
local surround = require("surround")

vim.keymap.set("n", "ds", surround.delete_surround)
vim.keymap.set("n", "ys", surround.add_surround, { expr = true })
vim.keymap.set("n", "yss", surround.add_surround_line, { expr = true })
vim.keymap.set("x", "gs", function()
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
  surround.visual_surround()
end)
```

## License

MIT
