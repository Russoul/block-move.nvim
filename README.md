# block-move.nvim

Move a rectangular column selection in any direction — up, down, left, or right — one step at a time.

The selected column range is exchanged with adjacent content across all rows of the selection simultaneously. Moving onto a shorter line pads it with spaces. Moving below the last line of the buffer inserts a new one. Moving left is blocked when the selection is already at column 1.

## Requirements

Neovim 0.7+

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'Russoul/block-move.nvim',
  config = function()
    require('block-move').setup({
      keymaps = {
        up    = '<C-i>',
        down  = '<C-k>',
        left  = '<C-j>',
        right = '<C-l>',
      },
    })
  end,
}
```

### [pckr.nvim](https://github.com/lewis6991/pckr.nvim) / [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'Russoul/block-move.nvim',
  config = function()
    require('block-move').setup({ ... })
  end,
}
```

## Configuration

```lua
require('block-move').setup({
  -- Pass keymaps = false (or omit setup entirely) to skip keymap registration
  -- and wire the functions yourself.
  keymaps = {
    up    = '<C-i>',
    down  = '<C-k>',
    left  = '<C-j>',
    right = '<C-l>',
  },
})
```

All keymaps are set in visual mode (`v`). Set any key to `false` to skip that binding individually.

### Manual keymaps

If you prefer to set keymaps yourself:

```lua
require('block-move').setup()  -- or omit entirely

local bm = require('block-move')
vim.keymap.set('v', '<C-i>', bm.moveSelectionUp,    { noremap = true, silent = true })
vim.keymap.set('v', '<C-k>', bm.moveSelectionDown,  { noremap = true, silent = true })
vim.keymap.set('v', '<C-j>', bm.moveSelectionLeft,  { noremap = true, silent = true })
vim.keymap.set('v', '<C-l>', bm.moveSelectionRight, { noremap = true, silent = true })
```

## API

| Function | Description |
|---|---|
| `require('block-move').moveSelectionUp()` | Move the selection up one row |
| `require('block-move').moveSelectionDown()` | Move the selection down one row |
| `require('block-move').moveSelectionLeft()` | Move the selection left one column |
| `require('block-move').moveSelectionRight()` | Move the selection right one column |
| `require('block-move').setup(opts)` | Register keymaps (see above) |

## How it works

The plugin operates on the column range defined by the `'<` and `'>` marks (set whenever you make a visual selection). It reads the column slice from every row of the selection simultaneously, then writes back the rotated result in one atomic operation. All rows participate in the same write, so there are no partial updates.

- **Vertical moves**: the selected column slice rotates through the adjacent row — the content below (or above) fills in on the opposite end.
- **Horizontal moves**: the selected column slice swaps with the single character immediately to its right (or left) on every row. The move is blocked if any row has no room on the requested side.

All column arithmetic is done in visual character columns, so multibyte characters are handled correctly.

## License

[GPL-3.0](LICENSE)
