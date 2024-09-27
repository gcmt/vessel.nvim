# Vessel.nvim

Interactive wrapper around the `:marks` and `:jumps` commands. Also provides the ability to set/unset a local or global mark by automatically choosing the letter for you.

## Setup

In order to create commands and potentially override any default option you can call the usual `setup` function by passing one single optional `table` as argument.

Calling the `setup` function is not required for using the plugin as internal `<Plug>` mappings are automatically created and *api* functions are lazily defined and ready to be used.

**Commands are not automatically created**. In order to create them, you can override the `create_commands` option. As you can see, you can even decide the commands names.

```lua
require("vessel").setup({
  ...
    create_commands = true,
    commands = {
      view_marks = "Marks",
      view_jumps = "Jumps"
    },
  },
  ...
})
```

Any option override you pass to the `setup` function will persist until you exit *NeoVim* or call the `setup` function again.

All *api* calls also accept a single optional `table` argument you can use to further override anything provided previously via the `setup` function.

## Marks list

### Mappings

```lua
-- Using internal mappings
vim.keymap.set("n", "gm", "<Plug>(VesselViewMarks)")
vim.keymap.set("n", "m.", "<Plug>(VesselSetLocalMark)")
vim.keymap.set("n", "m,", "<Plug>(VesselSetGlobalMark)")

-- Using api functions directly
vim.keymap.set("n", "gm", function()
    -- Overrides any default option and anything provided to the `setup` function
    require('vessel').view_marks({ lazy_load_buffers = false })
end)
vim.keymap.set("n", "m.", require('vessel').set_local_mark)
vim.keymap.set("n", "m,", require('vessel').set_global_mark)
```

### Commands and API

#### Setting a buffer-local mark

- `require("vessel").set_local_mark(opts)`

Automatically set a local mark (lowercase) on the current line. Local marks are only visible inside the current buffer. If you call the function (or execute the command) again on a marked line, the mark will be removed. Takes a single optional `opts` table argument if you want to override the default options or and every option you provided to the `setup` function.

#### Setting a global mark

- `require("vessel").set_global_mark(opts)`

Automatically set a gloabl mark (uppercase) on the current line. Global marks are also visible outside the current buffers. If you call the function (or execute the command) again on a marked line, the mark will be removed. Takes a single optional `opts` table argument if you want to override the default options or the ones you passd to the `setup` function.

#### View marks

- `:Marks` (customizable via: `{ commands = { view_marks = "Marks" } }`)
- `require("vessel").view_marks(opts)`

Open a nicely formatted window with all defined `[a-z][A-Z]` marks. By default, you can:

- Close the window with `q` or `<esc>`
- Move up and down with `j` and `k`
- Delete the mark on the current line with `d`
- Jump to the mark (or path) under cursor with `l` or `<cr>`
- Jump to the mark (or path) under cursor with `K` (does no change the jumplist)
- Open the mark under cursor in a vertical split with `v`
- Open the mark under cursor in a vertical split with `V` (does not change the jumplist)
- Open the mark under cursor in a horizontal split with `s`
- Open the mark under cursor in a horizontal split with `S` (does not change the jumplist)
- Open the mark under cursor in a new tab with `t`
- Open the mark under cursor in a new tab with `t` (does not change the jumplist)

## Jump list setup

### Mappings

```lua
-- Using internal mappings
vim.keymap.set("n", "gl", "<Plug>(VesselViewJumps)")
vim.keymap.set("n", "gL", "<Plug>(VesselViewLocalJumps)")

-- Using api functions directly
vim.keymap.set("n", "gl", function()
    -- Overrides any default option and anything provided to the `setup` function
    require('vessel').view_marks({ max_height = 90 })
end)
vim.keymap.set("n", "gL", require('vessel').view_local_jumps)
```

### Commands and API

#### Viewing the jump list

- `:Jumps` (customizable via: `{ commands = { view_jumps = "Jumps" } }`)
- `require("vessel").view_jumps(opts, filter_func)`

Open a nicely formatted window with the jumlist for the current window. By default jumps to empty lines are hidden and so are invalid jump entries. Jumps are displayed top to bottom, most recent on top.

- Close the window with `q` or `<esc>`
- Move up and down with `j` and `k`
- Clear the whole jumplist with `C`
- Jump to the entry under cursor with `l` or `<cr>`
- Use `<c-o>` or `<c-i>` (also with a `count`) as you would normally do to traverse the jump list. While `<c-i>` jumps to more recent jump positions, `<c-o>` jumps backwards.

As you can see, `view_jumps(opts, filter_func)` takes an optional `filter_func` function argument that will be used to filter out entries from the jump list. This function takes two parameters:

- the `jump` currently being filtered
- a `context` table parameter that contains information about the current window/buffer.

```lua
-- Example of a filter function used to filter out
-- jumps outside the current working directory
vim.keymap.set("n", "gL", function()
	require('vessel').view_jumps({}, function(jump, context)
		return vim.startswith(jump.bufpath, vim.fn.getcwd() .. "/")
	end)
end)
```

#### Viewing local jumps only

- `require("vessel").view_local_jumps(opts)`

Like `view_jumps(opts)` but only shows jump entries for the current buffer.
