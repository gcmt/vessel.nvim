<div align="center">
    <h1>vessel.nvim</h1>
    <img src="https://img.shields.io/badge/status-active-green.svg">
    <img src="https://img.shields.io/badge/release-2.1.0-green.svg">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg">
    <p></p>
    <p>Better ergonomics around Neovim mark list, buffer list and jump list.</p>
</div>

## Features

- Workflow still centered around native functionality.
- Highly customizable look and feel thanks to custom formatters and an extensive range of options.
- Provides useful shortcuts for setting marks automatically without having to pick a letter by yourself.
- Change and delete marks more effectively directly from the interactive mark list window.
- Delete and "resurrect" buffers directly from the buffer list window.
- *Pin* important buffers and quickly access them even from outside the buffer list window.

## Table of Contents

- [Features](#features)
- [Setup](#setup)
- [Windows](#windows)
  - [Mark List Window](#mark-list-window)
  - [Jump List Window](#jump-list-window)
  - [Preview Window](#preview-window)
  - [Buffer List Window](#buffer-list-window)
  - [Pinned Buffers](#pinned-buffers)
  - [Buffer List Tree View](#buffer-list-tree-view)
- [API](#api)
  - [Mark List API](#mark-list-api)
  - [Jump List API](#jump-list-api)
  - [Buffer List API](#buffer-list-api)
  - [Mark Object](#mark-object)
  - [Jump Object](#jump-object)
  - [Buffer Object](#buffer-object)
  - [Modes](#modes)
  - [Autocommand Events](#autocommand-events)
- [Configuration](#configuration)
  - [Options Validation](#options-validation)
  - [Common Options](#common-options)
  - [Commands Options](#commands-options)
  - [Window Options](#window-options)
  - [Preview Window Options](#preview-window-options)
  - [Jump List Options](#jump-list-options)
  - [Mark List Options](#mark-list-options)
  - [Buffer List Options](#buffer-list-options)
- [Formatters](#formatters)
  - [Example Formatters](#example-formatters)
  - [Formatter Functions Signatures](#formatter-functions-signatures)
- [LICENSE](#LICENSE)

## Setup

You can install the plugin with your favorite plugin manager.

The plugin provides a couple of basic commands to get you started:

- `:Marks` to open up a nicely formatted window with all defined `[a-z][A-Z]` marks
- `:Jumps` to open up a window with the jump list
- `:Buffers` to open up a window with the buffer list

**Commands are not automatically created**, so in order to create them you need to call the usual `setup` function and set the `create_commands` option. As you can see below, you can even change their default names if you wish to do so. If you prefer using mappings instead, skip ahead to the next section.

```lua
require("vessel").setup({
  create_commands = true,
  commands = { -- not required unless you want to customize each command name
    view_marks = "Marks",
    view_jumps = "Jumps",
    view_buffers = "Buffers"
  }
})
```

Calling the `setup` function is not required for using the plugin as internal `<plug>` mappings are automatically set up for you.

### Mark List Mappings

| Plug Mapping                      | Action                                                                      |
|-----------------------------------|-----------------------------------------------------------------------------|
| `<plug>(VesselViewMarks)`         | Show all *global* (uppercase) and local *marks* (lowercase) grouped by file.|
| `<plug>(VesselViewLocalMarks)`    | Show only *local* (lowercase) marks.                                        |
| `<plug>(VesselViewGlobalMarks)`   | Show only *global* (uppercase) marks.                                       |
| `<plug>(VesselViewBufferMarks)`   | Show both *local* and *global* marks in the current file.                   |
| `<plug>(VesselViewExternalMarks)` | Show only *global* marks belonging to other files.                          |
| `<plug>(VesselSetLocalMark)`      | Automatically set/unset a *local* mark on the current line.                 |
| `<plug>(VesselSetGlobalMark)`     | Automatically set/unset a *global* mark on the current line.                |

### Jump List mappings

| Plug Mapping                      | Action                                                                      |
|-----------------------------------|-----------------------------------------------------------------------------|
| `<plug>(VesselViewJumps)`         | Show the whole jump list.                                                   |
| `<plug>(VesselViewLocalJumps)`    | Show only jumps inside the current file.                                    |
| `<plug>(VesselViewExternalJumps)` | Show only jumps outside the current file.                                   |

### Buffer List Mappings

| Plug Mapping                | Action                                                                                                            |
|-----------------------------|-------------------------------------------------------------------------------------------------------------------|
| `<plug>(VesselViewBuffers)` | Show the buffer list. Only *normal listed buffers* will be displayed.                                             |
| `<plug>(VesselPinnedNext)`  | Switch to the next buffer in the pinned list (relative to buffer `%`). See [Pinned Buffers](#pinned-buffers).     |
| `<plug>(VesselPinnedPrev)`  | Switch to the previous buffer in the pinned list (relative to buffer `%`). See [Pinned Buffers](#pinned-buffers). |

Both `<plug>(VesselPinnedNext)` and `<plug>(VesselPinnedPrev)` will fall back respectively to the first and last buffer in the pinned list in case the current buffer is not in the pinned list as well. See also option [buffers.wrap_around](#bufferswrap_around).

> [!NOTE]
> - A *normal buffer* is a buffer with the `buftype` option empty.
> - Unlisted buffers can be toggled later directly inside the buffer list window.

### Example Mappings

Here how to use `<plug>` mappings in lua

```lua
vim.keymap.set("n", "gl", "<Plug>(VesselViewLocalJumps)")
vim.keymap.set("n", "gL", "<Plug>(VesselViewExternalJumps)")
```

and vimscript

```vim
nnoremap m. <plug>(VesselSetLocalMark)
nnoremap m, <plug>(VesselSetGlobalMark)
```

## Windows

### Mark List Window

![Marklist](assets/marks_dark.png "Mark list preview.")

By default the mark list window shows all global and local marks grouped by the file they belong to. By default, marks are sorted by line number. You can change the default sorting with the [marks.sort_marks](#markssort_marks) option.

Once inside the window, the following mappings are available:

| Mapping      | Action                                                                                    |
|--------------|-------------------------------------------------------------------------------------------|
| `q`, `<ESC>` | Close the floating window.                                                                |
| `<C-J>`      | Move to the next mark group (path header).                                                |
| `<C-K>`      | Move to the previous mark group (path header).                                            |
| `d`          | Delete the mark under cursor. Pressing `d` on the file path will delete all of its marks. |
| `l`, `<CR>`  | Jump to the mark (or path) under cursor.                                                  |
| `o`          | Jump to the mark under cursor (does not change the jump list).                            |
| `v`          | Open the mark under cursor in a vertical split.                                           |
| `V`          | Open the mark under cursor in a vertical split with (does not change the jump list).      |
| `s`          | Open the mark under cursor in a horizontal split.                                         |
| `S`          | Open the mark under cursor in a horizontal split (does not change the jump list).         |
| `t`          | Open the mark under cursor in a new tab.                                                  |
| `T`          | Open the mark under cursor in a new tab (does not change the jump list).                  |
| `<SPACE>`    | Cycle sorting type. It will be remembered once you close and reopen the window.           |
| `m{a-zA-Z}`  | Change the mark under cursor.                                                             |
| `'{a-z-A-Z}` | Jump directly to a mark.

### Jump List Window

![Jumplist](assets/jumps_dark.png "Jump list preview.")

By default the jump list window shows the entire jump list with jumps spanning multiple files. Jumps are displayed top to bottom, with the most recent jump being on top. The cursor is automatically placed on the current position in the jump list. On the left column you can see jump positions relative to the current one. You can use those relative position as a count to `<c-o>` and `<c-i>`.

Once inside the window, the following mappings are available:

| Mapping      | Action                                                                                         |
|--------------|------------------------------------------------------------------------------------------------|
| `l`, `<CR>`  | Jump to the line under cursor.                                                                 |
| `q`, `<ESC>` | Close the floating window.                                                                     |
| `C`          | Clear the entire jump list.                                                                    |
| `<C-O>`      | Move backwards in the jump list (towards the bottom).                                          |
| `<C-I>`      | Move forward in the jump list (towards the top).                                               |

> [!TIP]
>  As a count to `<C-O>` and `<C-I>`, you can use the relative number displayed on the left column.

> [!NOTE]
> The relative positions you see by default on the left column are not the **real relative positions** you would use as a count outside the jump list window. This is because the list can be filtered and you could potentially see big gaps between these positions otherwise.

### Preview Window

![Preview Window](assets/preview_dark.png "Preview window.")

By default both mark and jump lists have the preview window enabled. In this window you can see context of the line under cursor. To disable this feature you can use respectively the options [marks.preview](#markspreview) and [jumps.preview](#jumpspreview). The option [window.gravity](#windowgravity) controls how both the windows are positioned relative to each other.

See also [Preview Window Options](#preview-window-options).

### Buffer List Window

![Jumplist](assets/buffers_dark.png "Buffer list preview.")

By default the buffer list window shows all the normal buffers with the `listed` option set. Showing *unlisted* buffers can be toggled with the press of a key. By default buffers are sorted by their directory name. Head over to the [configuration section](#buffer-list-options) and look for the `sort_buffers` option to see how you can customize buffer sorting.

Once inside the window, the following mappings are available:

| Mapping      | Action                                                                                                                                  |
|--------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `q`, `<ESC>` | Close the floating window.                                                                                                              |
| `l`, `<CR>`  | Edit the buffer under cursor. Takes a count. Also expand a collapsed directory in [tree mode](#buffer-list-tree-view).                  |
| `t`          | Edit the buffer undeer cursor in a new tab.                                                                                             |
| `s`          | Edit the buffer under cursor in a horizontal split.                                                                                     |
| `v`          | Edit the buffer under cursor in a vertical split.                                                                                       |
| `d`          | Delete the buffer under cursor. Fails if there is any unsaved change. Executes `:bdelete` on the buffer.                                |
| `D`          | Force delete the buffer under cursor. **All unsaved changes will be lost!** Executes `:bdelete!` on the buffer.                         |
| `w`          | Wipe buffer under cursor. Fails if there is any unsaved change. Executes `:bwipeout` on the buffer.                                     |
| `W`          | Force wipe the buffer under cursor. **All unsaved changes will be lost!** Executes `:bwipeout!` on the buffer.                          |
| `<SPACE>`    | Cycle sorting type. It will be remembered once you close and reopen the window.                                                         |
| `a`          | Toggle showing *unlisted* buffers (Buffers on which you executed `:bdelete`).                                                           |
| `p`          | Pin/unpin the buffer under cursor.                                                                                                      |
| `P`          | Add to the buffer list the directory of the the buffer under cursor. See also [directory handler](#buffersdirectory_handler).           |
| `<C-X>`      | Decrease the buffer position in the *pinned list* (moves the buffer up).                                                                |
| `<C-A>`      | Increase the buffer position in the *pinned list* (moves the buffer down).                                                              |
| `g`          | Create or destroy group under cursor. See [Buffer List Tree View](#buffer-list-tree-view).                                              |
| `h`          | Collapse the directory under cursor. If a buffer is selected, its parent directory will be collapsed.                                   |

> [!NOTE]
> Don't be afraid to delete buffers. You can still re-open them later by simply toggling *unlisted buffers* and re-editing them. This can help keeping the buffer list clean and tidy. On the other end, by wiping out the buffer you won't be able to reopen it directly from the buffer list and you'll need to use other means. See `:help :bdelete` and `:help :bwipeout` for the specific effects that each command has on buffers.

> [!TIP]
> The mappings `l` or `<cr>` ([buffers.mappings.edit](#buffersmappingsedit)) take a line number as a count. When the [buffers.quickjump](#buffersquickjump) option is off and [line numbers are shown](#windownumber), you can simply type the line number and then press `l` or `<cr>` to instantly edit the buffer on that line.

### Pinned Buffers

Pinned buffers are buffers that always stay at the top of the window and and are not influenced by the current sort type. Together they form the *pinned list* and are separated from other buffers by a [separator](#bufferspin_separator).

This list is particularly useful when combined with the [buffers.quickjump](#buffersquickjump) option. With this option enabled, you can quickly jump to the top `[1-9]` buffers just by pressing a number. Buffers positions follow the natural order of line numbers so, in order to select the right buffer, you need to either enable line numbers for the whole window with the option [window.number](#windownumber) or, if you only want to display numbers for the *pinned list*, the option [buffers.show_pin_positions](#buffersshow_pin_positions).

The order of buffers in the *pinned list* can be manually adjusted. See mappings [buffers.pin_increase](#bufferspin_increase) and [buffers.pin_decrease](#bufferspin_decrease).

> [!NOTE]
> When enabled, the `buffers.quickjump` also works for unpinned buffers, but it's going to be less effective since you can't control the buffers positions unless they are in the *pinned list*.

#### Pinned buffers navigation

You can switch to *pinned buffers* even from outside the buffer list window. Use the provided [mappings](#buffer-list-mappings) `<plug>(VesselPinnedNext)` and `<plug>(VesselPinnedPrev)` or directly use the [Buffers API](#buffer-list-api). See also option [buffers.wrap_around](#bufferswrap_around).

### Buffer List Tree View

![TreeView](assets/treeview_dark.png "Buffer list tree view.")

With *tree view* enabled, all buffers will be grouped and displayed as multiple directory trees, one for the *current working directory*, one for the *home directory*, and one for the *root directory*. *Tree view* can be enabled with the option [buffers.view](#buffersview).

You can create as many additional separate trees as you want by pressing `g` on a directory or buffer. A new tree root will be created for that directory and all the contained buffers will be grouped under that tree. Buffers will always be grouped by the most specific tree root that matches their path. Note that if you press `g` on a file, a new tree will be created for its parent directory instead.

You can delete a group by pressing `g` again on the group and buffers will be re-grouped automatically in other trees. You can customize the default `g` mapping with the option [buffers.mappings.toggle_group](#buffersmappingstoggle_group).

To keep things organized you also have the possibility to hide buffers by collapsing directories with `h`. You can then expand them again with `l` or `<CR>`. See [buffers.mappings.collapse_directory](#buffersmappingscollapse_directory) option.

An option you might want to check out is [buffers.directories_first](#buffersdirectories_first), that controls whether directories are ordered first or last.

> [!NOTE]
> *Pinned* buffers will always be displayed on top as a flat list and won't be displayed along other buffers in directory trees.

## API

All *API* functions take a single optional `opts` table argument if you want to override the default options or every option you passed to the `setup` function.

### Mark List API

| Function                               | Action                                                       |
|----------------------------------------|--------------------------------------------------------------|
| `vessel.view_marks(opts, filter_func)` | Show all *global* (uppercase) and *local* marks (lowercase). |
| `vessel.view_local_marks(opts)`        | Show only *local* (lowercase) marks.                         |
| `vessel.view_global_marks(opts)`       | Show only *global* (uppercase) marks.                        |
| `vessel.view_buffer_marks(opts)`       | Show both *local* and *global* marks in the current file.    |
| `vessel.view_external_marks(opts)`     | Show only *global* marks belonging to different files.       |
| `vessel.set_local_mark(opts)`          | Automatically set/unset a *local* mark on the current line.  |
| `vessel.set_global_mark(opts)`         | Automatically set/unset a *global* mark on the current line. |

`filter_func` is a function used to filter out entries in the mark list. If the function returns `false`, the mark won't be displayed. The function takes two arguments:

- [`mark`](#mark-object) *table* parameter representing the mark currently being filtered.
- [`context`](#context-object) *table* parameter that contains information about the current window/buffer.

```lua
-- Example usage of a filter function to show only lowercase marks
vim.keymap.set("n", "gm", function()
  require('vessel').view_marks({}, function(mark, context)
    return string.match(mark.mark, "%l")
  end)
end)
```

### Jump List API

| Function                               | Action                                    |
|----------------------------------------|------------------------------------------ |
| `vessel.view_jumps(opts, filter_func)` | Show the whole jump list.                 |
| `vessel.view_local_jumps(opts)`        | Show only jumps inside the current file.  |
| `vessel.view_external_jumps(opts)`     | Show only jumps outside the current file. |

`filter_func` is a function used to filter out entries in the jump list. If the function returns `false`, the entry won't be displayed. The function takes two arguments:

- [`jump`](#jump-object) *table* parameter representing the jump entry currently being filtered.
- [`context`](#context-object) *table* parameter that contains information about the current window/buffer.

```lua
-- Usage of a filter function to filter out jumps outside the current working directory
vim.keymap.set("n", "gL", function()
  require('vessel').view_jumps({}, function(jump, context)
    return vim.startswith(jump.bufpath, vim.fn.getcwd() .. "/")
  end)
end)
```

### Buffer List API

| Function                                       | Action                                                                                       |
|------------------------------------------------|----------------------------------------------------------------------------------------------|
| `vessel.view_buffers(opts?, filter_func?)`     | Show the buffer list. Only *normal listed* buffers will be displayed.                        |
| `vessel.get_pinned_next(bufnr?)`               | Get buffer number of the buffer after `bufnr` (deafults to buffer `%`) in the pinned list.   |
| `vessel.get_pinned_prev(bufnr?)`               | Get buffer number of the buffer before `bufnr` (deafults to buffer `%`) in the pinned list.  |
| `vessel.get_pinned_list()`                     | Get list of all buffer numbers in the pinned list.                                           |

> [!NOTE]
> - A *normal buffer* is a buffer with the `buftype` option empty.
> - Unlisted buffers can be toggled later directly inside the buffer list window.

`filter_func` is a function used to filter out entries in the buffer list. If the function returns `false`, the buffer won't be displayed. The function takes two arguments:

- [`buffer`](#buffer-object) *table* parameter representing the buffer currently being filtered.
- [`context`](#context-object) *table* parameter that contains information about the current window/buffer.

```lua
-- Example usage of a filter function to show only init.lua files
vim.keymap.set("n", "gm", function()
  require('vessel').view_buffers({}, function(buffer, context)
    return vim.fs.basename(buffer.path) == "init.lua"
  end)
end)
```

### Context Object

Throughout the *API* documentation we will refer to the `context` as something that contains information about the current window/buffer, that is the buffer currently being edited. It is a `table` object with the following keys:

- `bufnr` Current buffer number
- `bufpath` Current buffer full path
- `wininfo` Window information as returned by `vim.fn.getwininfo()`
- `curpos` Cursor position as returned by `vim.fn.getcurpos()`

### Mark Object

The `Mark` object is `table` with the following keys:

- `mark` Mark letter.
- `lnum` Mark line number.
- `col` Mark column number.
- `line` Line on which the mark is positioned. Can be `nil` when the mark is invalid (`err` is not `nil`).
- `file` File the mark belongs to.
- `err` The mark has an error. Usually when file cannot be read or line does not exist anymore.

### Jump Object

The `Jump` object is `table` with the following keys:

- `current` Whether this jump is the current position in the jump list.
- `pos` Position of the jump in the jump list.
- `relpos` Position of the jump relative to the current position in the jump list.
- `bufnr` Buffer number.
- `bufpath` Buffer full path.
- `lnum` Jump line number.
- `col` Jump column number.
- `line` Line on which the jump is positioned. Can be `nil` when the mark is invalid (`err` is not `nil`).
- `err` The jump has an error. Usually when file cannot be read or line does not exist anymore.

### Buffer Object

The `Buffer` object is `table` with the following keys:

- `nr` Buffer number.
- `path` Buffer full path.
- `pinpos` Position in the pinned list. `-1` if buffer is not pinned.
- `listed` Whether the buffer is listed (visible in the buffer list).
- `isdirectory` Whether the buffer is a directory.
- `filetype` Buffer file type.
- `modified` Whether the buffer is modified/changed.
- `changedtick` Number total changes made to the buffer.
- `loaded` Whether the buffer is loaded.
- `hidden` Whether the buffer is hidden.
- `lastused` When the buffer was last used (unix time).

### Modes

Modes represent how you are jumping to the targeted location. They are defined as follows:

```lua
local util = require("vessel.util")
util.modes = {
  BUFFER = 1,
  SPLIT = 2,
  VSPLIT = 3,
  TAB = 4,
}
```

### Autocommand Events

The plugin defines `User` autocommands for certain events:

| Autocommand                    | Description                                                                       |
|--------------------------------|-----------------------------------------------------------------------------------|
| `User VesselBufferlistEnter`   | After the window is opened but before any content is displayed in the buffer.     |
| `User VesselBufferlistChanged` | Each time the buffer list window content changes.                                 |
| `User VesselMarklistEnter`     | After the window is opened but before any content is displayed in the buffer.     |
| `User VesselMarklistChanged`   | Each time the mark list window content changes                                    |
| `User VesselJumplistEnter`     | After the the window is opened but before any content is displayed in the buffer. |
| `User VesselJumplistChanged`   | Each time the jump list window content changes.                                   |

#### How to Setup Custom Mappings

The example below shows how you can setup your own mappings in the buffer window with the help of custom autocommand events. Specifically, with the snippet below we try to open a file browser directly from the buffer list if we realize the buffer we're looking for is not in the list.

In the example below we pretend `:FilExplorer` is a real command that takes a path as argument and opens up a file browser for that path.

```lua
local vessel_aug = vim.api.nvim_create_augroup("VesselCustom", { clear = true })
vim.api.nvim_create_autocmd("User", {
  group = vessel_aug,

  -- use the custom event name as pattern
  pattern = "VesselBufferlistEnter",

  callback = function()
    vim.keymap.set("n", ".", function()

      -- grab the selected buffer entry
      local sel = vim.b.vessel.get_selected()

        -- get_selected() can return nil on an empty list
      local path = sel and vim.fs.dirname(sel.path) or vim.fn.getcwd()

      -- close the buffer list window with the provided function
      vim.b.vessel.close_window()

      -- open up the file explorer for the given path
      vim.cmd("FileExplorer " .. vim.fn.fnameescape(path))

    end, { buffer = true })
  end,
})
```

For each list, the plugin sets a **buffer-local variable** named `vessel` that can be accessed directly with `vim.b.vessel`. This variable is a `table` that contains with the following keys:

- `map` A table mapping every line to a [mark](#mark-object), [jump](#jump-object) or [buffer](#buffer-object) on that line.
- `get_selected` Function to retrieve the *object* on the current line. Can return `nil` in case the list is empty.
- `close_window` Function to close the vessel window.

> [!IMPORTANT]
> This buffer-local variable is only available after the events `VesselMarklistChanged`, `VesselJumplistChanged` and `VesselBufferlistChanged`.

## Configuration

You can configure the plugin in different ways. The most obvious one is by calling the classic `setup` function. Calling this function is *required* if you want to create all predefined commands.

```lua
require("vessel").setup({
  create_commands = true,
  commands = {
    view_marks = "Marks",
    view_jumps = "Jumps"
    view_buffers = "Buffers"
  },
  ...
  window = {
    relativenumber = true
  }
  ...
})
```

The plugin also offers a more succinct way of setting options by providing an `opt` interface object

```lua
local vessel = require("vessel")
vessel.opt.highlight_on_jump = true
vessel.opt.window.max_height = 50
vessel.opt.marks.mappings.close = { "Q" }
vessel.opt.buffers.name_align = "right"
```

The third way of setting options is by directly passing a `table` argument to *API* functions. These options will override anything you passed previously to the `setup` function or set via the `opt` interface object.

```lua
vim.keymap.set("n", "g", function()
  require('vessel').view_jumps({ window = { max_height = 90 } })
end)
```

### Options Validation

Whether you use the `setup` function or set options via the `opt` interface, some basic *type* validation is alsways performed before options are actually being set. Specifically, if you decide to go the `opt` interface route, you should know that each option is validated the moment it is assigned. The moment you mistakenly try to assign a wrong value type to an option, you'll get a nice error message about what you need to fix, but everything will keep working and the option will retain its original value.

### Common Options

#### verbosity

Control how much noisy the plugin is. One of `vim.log.levels`.

```lua
vessel.opt.verbosity = vim.log.levels.INFO
```

#### highlight_on_jump, highlight_timeout

Set `cursorline` vim option for a brief period of time after a jump for `highlight_timeout` milliseconds.

```lua
vessel.opt.highlight_on_jump = false
vessel.opt.highlight_timeout = 250
```

#### jump_callback

Function executed after each jump. By default it just centers the cursor vertically unless `vim.o.jumpotions` is set to "view".

This function takes two parameters: [mode](#modes) and [context](#context-object).

```lua
vessel.opt.jump_callback = <function>
```

### Commands Options

#### create_commands

Whether to create commands or not.

> [!NOTE]
> You need to call the setup function to actually create commands

```lua
vessel.opt.create_commands = false
```

#### commands.view_marks, view_jumps, view_buffers

Customize each command name.

```lua
vessel.opt.commands.view_marks = "Marks"
vessel.opt.commands.view_jumps = "Jumps"
vessel.opt.commands.view_buffers = "Buffers"
```

### Window Options

#### window.gravity

Controls the positioning of the main popup window. This option have different effects whether the preview window is enabled or not.

Without the preview window enabled:
- `center` The window is centered vertically in the screen.
- `top` The window is positioned towards the top of the screen. The max top position is determined by the [window.max_height](#windowmax_height) option. The more this option is closer to `100` (100%), the highest the window will be positioned.

With the preview window enabled:
- `center`: When the preview window height is higher than the main popup window height, the latter will be vertically centered relative to the preview window.
- `top`: When the preview window height is higher than the main popup window height, the top margin of both windows will be aligned.

```lua
vessel.opt.window.gravity = "center"
```

#### window.max_height

Control the maximum height of the popup window as a percentage of the nvim UI.

```lua
vessel.opt.window.max_height = 80
```

#### window.cursorline

Enable/disable `cursorline` *neovim* option in the window.

```lua
vessel.opt.window.cursorline = true
```

#### window.number

Enable/disable `number` *neovim* option in the window.

```lua
vessel.opt.window.number = false
```

#### window.relativenumber

Enable/disable `relativenumber` *neovim* option in the popup window.

```lua
vessel.opt.window.relativenumber = false
```

#### window.options

Control how the popup looks. These options are passed directly to the `vim.api.nvim_open_win()` function. See `:help api-floatwin`.

```lua
vessel.opt.window.options.style = "minimal"
vessel.opt.window.options.border = "single"
```

#### window.width

Width of the popup window as a percentage of the *Neovim* UI. This can be either a function or a table with 2 numbers.

The first value is the popup width with no side preview popup displayed, the second value is the total width of both the main popup and the preview popup when the latter is displayed on the right side of the main popup.

```lua
vessel.opt.window.width = <function>
```

Below the default implementation:

```lua
function popup_width()
  return vim.o.columns < 120 and { 90, 90 } or { 75, 90 }
end
```

### Preview Window Options

#### preview.options

Control how the preview popup looks. These options are passed directly to the `vim.api.nvim_open_win()` function. See `:help api-floatwin`.

```lua
vessel.opt.preview.options.style = "minimal"
vessel.opt.preview.options.border = "single"
```

#### preview.position

Whether to position the preview popup on the right side or on the bottom side of the main popup window. Can be either `right` or `bottom`.

```lua
vessel.opt.preview.position = "right"
```

#### preview.width

Width of the preview window as a percentage of [window.width](#windowwidth).

```lua
vessel.opt.preview.width = 50
```

#### preview.width_threshold

If the main popup width is less than *this* amount of columns, the preview popup is pushed to the bottom side of the main popup.

```lua
vessel.opt.preview.width_threshold = 80
```

#### preview.min_height

Minimum height of the preview window, expressed in lines.

```lua
vessel.opt.preview.min_height = 21
```

### Mark List Options

#### marks.preview

Enable or disable preview window. See the [Preview Window Options](#preview-window-options) section for how to customize it.

```lua
vessel.opt.marks.preview = true
```

#### marks.locals and maks.globals

The pool of marks the plugin chooses from when automatically picking the letter for you.

```lua
vessel.opt.marks.locals = "abcdefghijklmnopqrstuvwxyz"
vessel.opt.marks.globals = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
```
#### marks.sort_groups

Function used to sort groups. A group is a set of marks belonging to the same file.

```lua
vessel.opt.marks.sort_groups = function(a, b)
    return a > b
end
```
#### marks.sort_marks

List of functions used to sort marks in the each groups. First item is the function used by default the first time you open the window.

See also [marks.mappings.cycle_sort](#marksmappingscycle_sort).

```lua
local sorters = require("vessel.config.sorters")
vessel.opt.marks.sort_marks = { sorters.marks.by_lnum, sorters.marks.by_mark }
```
Available sorters are:
- `sorters.marks.by_lnum` Sort by mark line number.
- `sorters.marks.by_mark` Sort by mark letter (capitals first).

You can also define your own *sorter function*. The function must return two values:
- A function with the signature: `function(MarkA, MarkB) return boolean end`
- A description string that will be used to give feedback to the user when cycling between these function, or empty string for no feedback

Example function:

```lua
function sort_by_lnum()
  local fn = function(a, b)
    return a.lnum < b.lnum
  end
  return fn, "sorting by line number"
end
```

#### marks.path_style

Controls the style of the file path header. Can be one of:
- `full` Full file path
- `short` Shortest unique suffix among all paths
- `relhome` Relative to the home directory
- `relcwd` Relative to the current working directory

> [!NOTE]
> Has effect only when using default formatters.

```lua
vessel.opt.marks.path_style = "relcwd"
```

#### marks.toggle_mark

Enable/disable unsetting a mark when trying to mark an alredy marked line.

```lua
vessel.opt.marks.toggle_mark = true
```

#### marks.use_backtick

Use backtick instead of apostrophe for jumping to marks. See `:help mark-motions`.

```lua
vessel.opt.marks.use_backtick = false
```

#### marks.not_found

Message used when the mark list is empty.

```lua
vessel.opt.marks.not_found = "No marks found"
```

#### marks.move_to_first_mark

Position the cursor on the first line of a mark group.

```lua
vessel.opt.marks.move_to_first_mark = true
```

#### marks.move_to_closest_mark, marks.proximity_threshold

Position the cursor on the closest mark relative to the current position in the buffer. If a mark is farther from the cursor than `proximity_threshold` lines, it won't be considered.

```lua
vessel.opt.marks.move_to_closest_mark = true
vessel.opt.marks.proximity_threshold = 50
```

#### marks.force_header

Force displaying the group header (file path) even when there is just one group.

> [!NOTE]
> Has effect only when using default formatters.

```lua
vessel.opt.marks.force_header = false
```

#### marks.decorations

Decorations used as prefix to each formatted mark. Last item is for last entries in each group.

> [!NOTE]
> Has effect only when using default formatters.

```lua
vessel.opt.marks.decorations = { "├ ", "└ " }
```

#### marks.show_colnr

Show/hide mark column number.

> [!NOTE]
> Has effect only when using default formatters.

```lua
vessel.opt.marks.show_colnr = false
```

#### marks.strip_lines

Strip leading white spaces from lines.

> [!NOTE]
> Has effect only when using default formatters.

```lua
vessel.opt.marks.strip_lines = true
```

#### marks.formatters.mark, marks.formatters.header

Functions used to format each mark / group header line. See [Formatters](#Formatters) section for more info.

```lua
vessel.opt.marks.formatters.mark = <function>
vessel.opt.marks.formatters.header = <function>
```

#### marks.highlights.*

Highlight groups used by default formatters.

> [!NOTE]
> Have effect only when using the default formatters.

```lua
vessel.opt.marks.highlights.path = "Directory"
vessel.opt.marks.highlights.not_loaded = "Comment"
vessel.opt.marks.highlights.decorations = "NonText"
vessel.opt.marks.highlights.mark = "Keyword"
vessel.opt.marks.highlights.lnum = "LineNr"
vessel.opt.marks.highlights.col = "LineNr"
vessel.opt.marks.highlights.line = "Normal"
```

#### marks.mappings.close

Close the mark list window.

```lua
vessel.opt.marks.mappings.close = { "q", "<esc>" }
```

#### marks.mappings.delete

Delete the mark under cursor.

```lua
vessel.opt.marks.mappings.delete = { "d" }
```

#### marks.mappings.next_group

Move to the next group header.

```lua
vessel.opt.marks.mappings.next_group = { "<c-j>" }
```

#### marks.mappings.prev_group

Move to the previous group header.

```lua
vessel.opt.marks.mappings.prev_group = { "<c-k>" }
```

#### marks.mappings.jump

Jump to the mark (or path) under cursor.

```lua
vessel.opt.marks.mappings.jump = { "l", "<cr>" }
```

#### marks.mappings.keepj_jump

Jump to the mark under cursor (does not change the jump list).

```lua
vessel.opt.marks.mappings.keepj_jump = { "o" }
```

#### marks.mappings.tab

Open the mark under cursor in a new tab.

```lua
vessel.opt.marks.mappings.tab = { "t" }
```

#### marks.mappings.keepj_tab

Open the mark under cursor in a new tab (does not change the jump list).

```lua
vessel.opt.marks.mappings.keepj_tab = { "T" }
```

#### marks.mappings.split

Open the mark under cursor in a horizontal.

```lua
vessel.opt.marks.mappings.split = { "s" }
```

#### marks.mappings.keepj_split

Open the mark under cursor in a horizontal split (does not change the jump list).

```lua
vessel.opt.marks.mappings.keepj_split = { "S" }
```

#### marks.mappings.vsplit

Open the mark under cursor in a vertical split.

```lua
vessel.opt.marks.mappings.vsplit = { "v" }
```

#### marks.mappings.keepj_vsplit

Open the mark under cursor in a vertical split with (does not change the jump list).

```lua
vessel.opt.marks.mappings.keepj_vsplit = { "V" }
```

#### marks.mappings.cycle_sort

Cycle sorting functions. See also [marks.sort_marks](#markssort_marks).

```lua
vessel.opt.marks.mappings.cycle_sort = { "<SPACE>" }
```

### Jump List Options

#### jumps.preview

Enable or disable preview window. See the [Preview Window Options](#preview-window-options) section for how to customize it.

```lua
vessel.opt.jumps.preview = true
```

#### jumps.real_positions

Display real jump entries positions. There might be gaps when filters are applied to the list.

```lua
vessel.opt.jumps.real_positions = false
```

#### jumps.strip_lines

Strip leading white spaces from lines.

```lua
vessel.opt.jumps.strip_lines = false
```

#### jumps.filter_empty_lines

Filter jump entries that point to empty lines.

```lua
vessel.opt.jumps.filter_empty_lines = true
```

#### jumps.not_found

Message used when the jump list is empty.

```lua
vessel.opt.jumps.not_found = "Jump list empty"
```

#### jumps.indicator

Prefix used for each formatted jump entry. First item is the line of the current position in the jump list.

> [!NOTE]
> Has effect only when using the default formatter.

```lua
vessel.opt.jumps.indicator = { " ", " " }
```

#### jumps.show_colnr

Show/hide jump entries column numbers.

> [!NOTE]
> Has effect only when using the default formatter.

```lua
vessel.opt.jumps.show_colnr = false
```

#### jumps.formatters.jump

Functions used to format each jump entry line. See [Formatters](#Formatters) section for more info.

```lua
vessel.opt.jumps.formatters.jump = <function>
```

#### jumps.mappings.ctrl_o

Mapping used to move backwards in the jump list (to the bottom of the window). Takes a count.

```lua
vessel.opt.jumps.mappings.ctrl_o = "<c-o>"
```

#### jumps.mappings.ctrl_i

Mapping used to move forwards in the jump list (to the top of the window). Takes a count.

```lua
vessel.opt.jumps.mappings.ctrl_i = "<c-i>"
```

#### jumps.mappings.jump

Jump to the entry under cursor.

```lua
vessel.opt.jumps.mappings.jump = { "l", "<cr>" }
```

#### jumps.mappings.close

Close the jump list window.

```lua
vessel.opt.jumps.mappings.close = { "q", "<esc>" }
```

#### jumps.mappings.clear

Clear the jump list. Executes `:clearjumps`.

```lua
vessel.opt.jumps.mappings.clear = { "C" }
```

#### jumps.highlights.*

Highlight groups used by the default formatter.

```lua
vessel.opt.jumps.highlights.indicator = "Comment"
vessel.opt.jumps.highlights.pos = "LineNr"
vessel.opt.jumps.highlights.current_pos = "CursorLineNr"
vessel.opt.jumps.highlights.path = "Directory"
vessel.opt.jumps.highlights.lnum = "LineNr"
vessel.opt.jumps.highlights.col = "LineNr"
vessel.opt.jumps.highlights.line = "Normal"
vessel.opt.jumps.highlights.not_loaded = "Comment"
```

### Buffer List Options

#### buffers.view

Buffer list view mode. Can be one of:

- `flat` Buffers displayed as a simple list.
- `tree` Buffers displayed as directory a tree. Buffers will be grouped in different directory trees depending on the most specific path prefix match: one group for the current working directory, one for the home directory and one for the root directory.

> [!NOTE]
> In *tree view* mode, pinned buffers will still be displayed as a list.

```lua
vessel.opt.buffers.view = "flat"
```

#### buffers.wrap_around

When navigating to next/previous buffers in the pinned list with the [*API*](#buffer-list-api) or [`<plug>`](#buffer-list-mappings) mappings, wrap around the list when reaching its start or end.

```lua
vessel.opt.buffers.wrap_around = true
```

#### buffers.not_found

Message used when the buffer list is empty

```lua
vessel.opt.buffers.not_found = "Buffer list empty"
```

#### buffers.unnamed_label

Label used for unnamed buffers.

```lua
vessel.opt.buffers.unnamed_label = "[no name]"
```

#### buffers.quickjump

Remap numbers `[1-9]` in normal mode to quickly edit the 9 buffers at the top of the window.

```lua
vessel.opt.buffers.quickjump = true
```

#### buffers.directory_handler

Function called for buffers that are directories. By default assumes Netrw is enabled (vim.g.loaded_netrwPlugin == 1) and simply executes `:edit` command on the buffer. Can be useful to open up your favorite file explorer or fuzzy finder.

This function takes two parameters: `path` and [context](#context-object).

```lua
vessel.opt.buffers.directory_handler = <function>
```

#### buffers.sort_buffers

List of functions used to sort buffers. First item is the function used by default the first time you open the window.

See also [buffers.mappings.cycle_sort](#buffersmappingscycle_sort).

```lua
local sorters = require("vessel.config.sorters")
vessel.opt.buffers.sort_buffers = {
  sorters.buffers.by_path,
  sorters.buffers.by_basename,
  sorters.buffers.by_lastused,
  sorters.buffers.by_changes,
}
```

Available sorters are:
- `sorters.buffers.by_path` Sort by buffer directory.
- `sorters.buffers.by_basename` Sort by buffer basename.
- `sorters.buffers.by_lastused` Sort by last time the buffer was used/visited.
- `sorters.buffers.by_changes` Sort by the total number of changes made in the buffer.


You can also define your own *sorter function*. The function must return two values:
- A function with the signature: `function(BufferA, BufferB) return boolean end`
- A description string that will be used to give feedback to the user when cycling between these function, or empty string for no feedback

Example sorter function:

```lua
function sort_by_basename()
  local fn = function(a, b)
    return vim.fs.basename(a.path) < vim.fs.basename(b.path)
  end
  return fn, "sorting by basename"
end
```

#### buffers.sort_directories

Function used to sort directories.

```lua
vessel.opt.buffers.sort_directories = function(path_a, path_b)
    return path_a < path_b
end
```
#### buffers.directories_first

Whether directories should be put first or last in the buffer list or tree.

```lua
vessel.opt.buffers.directories_first = false
```

#### buffers.show_pin_positions

Whether line numbers are diplayed next to pinned buffers.

Useful when line numbers are not enabled for the window or the [buffers.quickjump](#buffersquickjump) option is enabled.

> [!NOTE]
> Has effect only when using the default formatter.

```lua
vessel.opt.buffers.show_pin_positions = true
```

#### buffers.tree_lines

Building blocks of the tree in [tree view](#buffersview) mode. All must have equal length.

> [!NOTE]
> Has effect only in [tree view](#buffersview) mode.

```lua
vessel.opt.buffers.tree_lines = { "│  ", "├─ ", "└─ ", "   " }
```

#### buffers.pin_separator

Character used as separator between the *pinned list* and the rest of the buffers. Use an empty string to hide the separator. Its color is controlled by the option [buffers.highlights.pin_separator](#buffershighlights).

See also [Pinned Buffers](#pinned-buffers).

```lua
vessel.opt.buffers.pin_separator = "─"
```

#### buffers.group_separator

Character used as separator between different [tree groups](#buffer-list-tree-view). Use an empty string to hide the separator.

The color can be set with the option [buffers.highlights.group_separator](#buffershighlights).

```lua
vessel.opt.buffers.group_separator = ""
```

#### buffers.bufname_align

How to align the buffer name. Can be one of:
- `left` Left alignment
- `right` Right alignment
- `none` No alignment

> [!NOTE]
> Has effect only when using the default formatter.

```lua
vessel.opt.buffers.bufname_align = "left"
```

#### buffers.bufname_style

Buffer name style. Can be one of:
- `basename` Buffer base name
- `unique` Shortest unique suffix among all paths
- `hide` Hide bufname completely

> [!NOTE]
> Has effect only when using the default formatter.

```lua
vessel.opt.buffers.bufname_style = "unique"
```

#### buffers.bufpath_style

Buffer path style. Can be one of:
- `full` Full file path
- `short` Shortest unique suffix among all paths
- `relhome` Relative to the home directory
- `relcwd` Relative to the current working directory
- `hide` Hide buffer path completely

> [!NOTE]
> Has effect only when using the default formatter.

```lua
vessel.opt.buffers.bufpath_style = "relcwd"
```

#### buffers.formatter_spacing

Spacing between formatted items (line numbers, bufname and bufpath).

> [!NOTE]
> Has effect only when using the default formatter.

```lua
vessel.opt.buffers.formatter_spacing =  " "
```

#### buffers.mappings.cycle_sort

Cycle sorting functions. See also [buffers.sort_buffers](#bufferssort_buffers).

```lua
vessel.opt.buffers.mappings.cycle_sort = { "<space>" }
```

#### buffers.mappings.toggle_pin

Toggle pinned status on the buffer under cursor.

See also [Pinned Buffers](#pinned-buffers).

```lua
vessel.opt.buffers.mappings.toggle_pin = { "p" }
```

#### buffers.mappings.toggle_group

Create new tree group for the parent directory of the selected buffer or directly for the selected directory.

> [!NOTE]
> Has effect only in tree view mode.

```lua
vessel.opt.buffers.mappings.toggle_group = { "g" }
```

#### buffers.mappings.collapse_directory

Collapse directory under cursor and hide all of its content. If a buffer is selected instead, its parent directory will be collapsed. To expand a collapsed directory, use [buffer.mappings.edit](#buffersmappingsedit)

> [!NOTE]
> Works only in tree view mode.

```lua
vessel.opt.buffers.collapse_directory = { "h" }
```

#### buffers.mappings.add_directory

Add to the buffer list the directory of the buffer under cursor.

```lua
vessel.opt.buffers.mappings.add_directory = { "P" }
```

#### buffers.mappings.pin_increment

Move the buffer under cursor down in the *pinned list*. The buffer is pinned if not already in the *pinned list*.

> [!NOTE]
> Incrementing the position essentially moves the buffer down.

See also [Pinned Buffers](#pinned-buffers).

```lua
vessel.opt.buffers.mappings.pin_increment = { "<c-a>" }
```

#### buffers.mappings.pin_decrement

Move the buffer under cursor up in the *pinned list*. The buffer is pinned if not already in the *pinned list*.

> [!NOTE]
> Decrementing the position essentially moves the buffer up.

See also [Pinned Buffers](#pinned-buffers).

```lua
vessel.opt.buffers.mappings.pin_decrement = { "<c-x>" }
```

#### buffers.mappings.toggle_unlisted

Toggle unlisted buffers.

```lua
vessel.opt.buffers.mappings.toggle_unlisted = { "a" }
```

#### buffers.mappings.edit

Edit the buffer under cursor.

```lua
vessel.opt.buffers.mappings.edit = { "l", "<cr>" }
```

#### buffers.mappings.tab

Edit the buffer under cursor in a new tab.

```lua
vessel.opt.buffers.mappings.tab = { "t" }
```

#### buffers.mappings.split

Edit the buffer under cursor in a horizontal split.

```lua
vessel.opt.buffers.mappings.split = { "s" }
```

#### buffers.mappings.vsplit

Edit buffer under cursor in a vertical split.

```lua
vessel.opt.buffers.mappings.vsplit = { "v" }
```

#### buffers.mappings.delete

Executes `:bdelete` on the buffer under cursor (fails with unsaved changes).

Basically sets the buffer unlisted. The buffer can then be re-openend by toggling unlisted buffers with [buffers.mappings.toggle_unlisted](#buffersmappingstoggle_unlisted).

```lua
vessel.opt.buffers.mappings.delete = { "d" }
```

#### buffers.mappings.force_delete

Executes `:bdelete!` on the buffer under cursor.

> [!CAUTION]
> All unsaved changes will be lost!

```lua
vessel.opt.buffers.mappings.force_delete = { "D" }
```

#### buffers.mappings.wipe

Executes `:bwipeout` buffer under cursor (fails with unsaved changes).

```lua
vessel.opt.buffers.mappings.wipe = { "w" }
```

#### buffers.mappings.force_wipe

Executes `:bwipeout!` on the buffer under cursor.

> [!CAUTION]
> All unsaved changes will be lost!

```lua
vessel.opt.buffers.mappings.force_wipe = { "W" }
```

#### buffers.mappings.close

Close the buffer list window.

```lua
vessel.opt.buffers.mappings.close = { "q", "<esc>" }
```

#### buffers.formatters.buffer

Functions used to format each buffer entry line. See [Formatters](#formatters) section for more info.

```lua
vessel.opt.buffers.formatters.buffer = <function>,
```

#### buffers.formatters.tree_root

Function used to format each tree root directory.

> [!NOTE]
> Used in *tree view* mode ([buffers.view](#buffersview)).

```lua
vessel.opt.buffers.formatters.tree_root = <function>
```

#### buffers.formatters.tree_directory

Function used to format each tree directory node.

> [!NOTE]
> Used in *tree view* mode ([buffers.view](#buffersview)).

```lua
vessel.opt.buffers.formatters.tree_directory = <function>
```

##### buffers.formatters.tree_buffer

Function used to format each tree buffer leave.

> [!NOTE]
> Used in *tree view* mode ([buffers.view](#buffersview)).

```lua
vessel.opt.buffers.formatters.tree_buffer = <function>
```

#### buffers.highlights.*

Highlight groups used by the default formatter.

```lua
vessel.opt.buffers.highlights.bufname = "Normal"
vessel.opt.buffers.highlights.bufpath = "Comment"
vessel.opt.buffers.highlights.unlisted = "Comment"
vessel.opt.buffers.highlights.directory = "Directory"
vessel.opt.buffers.highlights.modified = "Keyword"
vessel.opt.buffers.highlights.pin_position = "LineNr"
vessel.opt.buffers.highlights.pin_separator = "NonText"
vessel.opt.buffers.highlights.group_separator = "NonText"
vessel.opt.buffers.highlights.tree_root = "Keyword"
vessel.opt.buffers.highlights.tree_lines = "Comment"
vessel.opt.buffers.highlights.hidden_count = "Comment"
```

## Formatters

Formatters are functions that let you customize how each line of the floating window is going to look.

All formatter functions take four arguments: the object being formatted, the [context object](#context-object), a `meta` table object, and a `config` table object. They all should return a `string` and an optional special `table` used by the plugin for setting up highlighting.

Most of the time you'll want to highlight specific parts of the formatted line. To make things easier the plugin provides a special `format` function you can call in order to automatically generate the correct return values. This utility function is very similar to the lua native `string.format()`, but the unlike it, our format function only accepts `%s` placeholders.

```lua
> format = require("vessel.util").format
> line, hl = format("%s : %s %s", {"foo", "Normal"}, "bar", {"baz", "LineNr"})
> print(line)
foo : bar baz
> vim.inspect(hl)
{ {
    startpos = 1
    endpos = 3,
    hlgroup = "Normal",
}, {
    startpos = 11
    endpos = 13,
    hlgroup = "LineNr",
} }
```

### Example Formatters

```lua
local util = require("vessel.util")

-- Note: You can return nil from a header formatter to prevent
-- the line from being displayed in the list
local function header_formatter(path, meta, context, config)
    local path = meta.suffixes[path]
    return util.format("# %s", {path, "Directory"})
end

local function mark_formatter(mark, meta, context, config)
    -- different colors for uppercase and lowercase marks
    local hl = string.match(mark.mark, "%u") and "Blue" or "Red"
    return util.format(" [%s] %s:%s %s",
        {mark.mark, hl},
        {mark.lnum, "LineNr"},
        {mark.col, "LineNr"},
        {mark.line, "Normal"}
    )
end
```

In this more complex example we'll remove the header and display the file name on each line instead:

```lua
local util = require("vessel.util")
local vessel = require("vessel")

vessel.opt.marks.formatters.header = function(path, meta, context, config)
  return
end

vessel.opt.marks.formatters.mark = function(mark, meta, context, config)
    -- Makes sure each line number is vertically aligned
  local lnum_fmt = "%" .. #tostring(meta.max_lnum) .. "s"
  local lnum = string.format(lnum_fmt, mark.lnum)

  local line, line_hl
  if mark.line then
    -- strips leading white spaces from each line
    line = string.gsub(mark.line, "^%s+", "")
    line_hl = "Normal"
  else
    -- if line is nil, it could mean the mark is invalid
    line = mark.err or ""
    line_hl = "Comment"
  end

  -- Display a vertically aligned file name
  local path_fmt = "%-" .. meta.max_suffix .. "s" -- align file names
  local path = string.format(path_fmt, meta.suffixes[mark.file])

  return util.format(
    " [%s]  %s %s %s",
    { mark.mark, "Keyword" },
    { path, "Directory" },
    { lnum, "LineNr" },
    { line, line_hl }
  )
end
```

### Formatter Functions Signatures

#### marks.formatters.header

```lua
vessel.opt.marks.formatters.header = <function>
```

Controls how each group header (file path) in the mark list is formatted. Takes the following four arguments:

| Parameter | Description                                                                                                      |
|-----------|------------------------------------------------------------------------------------------------------------------|
| `path`    | The full path being formatted.                                                                                   |
| `context` | Table containing information about the current window/buffer. See the [context object](#context-object) section. |
| `config`  | Table containing the complete configuration.                                                                     |
| `meta`    | Table containing additional contextual information.                                                              |

The `meta` table has the following keys:

| Key            | Description                                                                 |
|----------------|-----------------------------------------------------------------------------|
| `groups_count` | Total number of groups.                                                     |
| `suffixes`     | Table mapping each full path to its shortest unique suffix among all paths. |
| `max_suffix`   | Maximum length among all suffixes above.                                    |

#### marks.formatters.mark

```lua
vessel.opt.marks.formatters.mark = <function>
```

Controls how each mark in the mark list is formatted. Takes the following four arguments:

| Parameter | Description                                                                                                      |
|-----------|------------------------------------------------------------------------------------------------------------------|
| `mark`    | The mark being formatted. See the [mark object](#mark-object) section.                                           |
| `context` | Table containing information about the current window/buffer. See the [context object](#context-object) section. |
| `config`  | Table containing the complete configuration.                                                                     |
| `meta`    | Table containing additional contextual information.                                                              |

 The `meta` table has the following keys:

| Key              | Description                                                                 |
|------------------|-----------------------------------------------------------------------------|
| `pos`            | Position of the mark being formatted in the group.                          |
| `is_last`        | Whether the mark being formatted is last in the group.                      |
| `groups_count`   | Total number of mark groups.                                                |
| `max_lnum`       | Highest line number among all mark groups.                                  |
| `max_col`        | Highest column number among all mark groups.                                |
| `max_group_lnum` | Highest line number in the current group.                                   |
| `max_group_col`  | Highest column number in the group.                                         |
| `suffixes`       | Table mapping each full path to its shortest unique suffix among all paths. |
| `max_suffix`     | Max string length among all suffixes above.                                 |

#### jumps.formatters.jump

```lua
vessel.opt.jumps.formatters.jump = <function>
```

Controls how each line of the jump list is formatted. Takes the following four arguments:

| Parameter | Description                                                                                                      |
|-----------|------------------------------------------------------------------------------------------------------------------|
| `jump`    | The jump being formatted. See the [jump object](#jump-object) section.                                           |
| `context` | Table containing information about the current window/buffer. See the [context object](#context-object) section. |
| `config`  | Table containing the complete configuration.                                                                     |
| `meta`    | Table containing additional contextual information.                                                              |

 The `meta` table has the following keys:

| Key                 | Description                                                                 |
|---------------------|-----------------------------------------------------------------------------|
| `jumps_count`       | Total number of jumps.                                                      |
| `current_line`      | Line number of the jump being formatted.                                    |
| `current_jump_line` | Line number of the current jump position.                                   |
| `max_lnum`          | Max line number among all jumps.                                            |
| `max_col`           | Max column number among all jumps.                                          |
| `max_relpos`        | Max relative number among all jumps.                                        |
| `max_basename`      | Max basename length among all jumps paths.                                  |
| `suffixes`          | Table mapping each full path to its shortest unique suffix among all paths. |
| `max_suffix`        | Max string length among all suffixes above.                                 |

#### buffers.formatters.buffer

```lua
vessel.opt.buffers.formatters.buffer = <function>
```

Controls how each line of the buffer list is formatted. Takes the following four arguments:

| Parameter | Description                                                                                                      |
|-----------|------------------------------------------------------------------------------------------------------------------|
| `buffer`  | The buffer being formatted. See the [buffer object](#buffer-object) section.                                     |
| `context` | Table containing information about the current window/buffer. See the [context object](#context-object) section. |
| `config`  | Table containing the complete configuration.                                                                     |
| `meta`    | Table containing additional contextual information.                                                              |

 The `meta` table has the following keys:

| Key            | Description                                                                 |
|----------------|-----------------------------------------------------------------------------|
| `current_line` | Line number of the buffer being formatted.                                  |
| `max_basename` | Max basename length among all buffer paths.                                 |
| `suffixes`     | Table mapping each full path to its shortest unique suffix among all paths. |
| `max_suffix`   | Max string length among all suffixes above.                                 |
| `pinned_count` | Number of pinned buffers.                                                   |

#### buffers.formatters.tree_buffer

```lua
vessel.opt.buffers.formatters.tree_buffer = <function>
```

Controls how each buffer is formatted in *tree view*. Takes the following four arguments:

| Parameter | Description                                                                                                      |
|-----------|------------------------------------------------------------------------------------------------------------------|
| `buffer`  | The buffer being formatted. See the [buffer object](#buffer-object) section.                                     |
| `context` | Table containing information about the current window/buffer. See the [context object](#context-object) section. |
| `config`  | Table containing the complete configuration.                                                                     |
| `meta`    | Table containing additional contextual information.                                                              |

The `meta` table has the following keys:

| Key            | Description                                                                 |
|----------------|-----------------------------------------------------------------------------|
| `prefix`       | Decoration lines of the tree line being rendered.                           |

#### buffers.formatters.tree_directory

```lua
vessel.opt.buffers.formatters.tree_directory = <function>
```

Controls how each directory is formatted in *tree view*. Takes the following four arguments:

| Parameter | Description                                                                                                      |
|-----------|------------------------------------------------------------------------------------------------------------------|
| `path`    | The path of the directory being formatted.                                                                       |
| `context` | Table containing information about the current window/buffer. See the [context object](#context-object) section. |
| `config`  | Table containing the complete configuration.                                                                     |
| `meta`    | Table containing additional contextual information.                                                              |

The `meta` table has the following keys:

| Key            | Description                                                                 |
|----------------|-----------------------------------------------------------------------------|
| `prefix`       | Decoration lines of the tree line being rendered.                           |

#### buffers.formatters.root_directory

```lua
vessel.opt.buffers.formatters.tree_root = <function>
```

Controls how each root directory is formatted in *tree view*. Takes the following four arguments:

| Parameter | Description                                                                                                      |
|-----------|------------------------------------------------------------------------------------------------------------------|
| `path`    | The tree root path of the directory being formatted.                                                             |
| `context` | Table containing information about the current window/buffer. See the [context object](#context-object) section. |
| `config`  | Table containing the complete configuration.                                                                     |
| `meta`    | Table containing additional contextual information.                                                              |

The `meta` table has the following keys:

| Key            | Description                                                                 |
|----------------|-----------------------------------------------------------------------------|
| `prefix`       | Decoration lines of the tree line being rendered.                           |


## License

This project is licensed under the MIT License. See the [LICENSE.txt](LICENSE.txt) file for details.
