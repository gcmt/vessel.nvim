---@module "defaults"

local buf_formatters = require("vessel.bufferlist.formatters")
local jumps_formatters = require("vessel.jumplist.formatters")
local marks_formatters = require("vessel.marklist.formatters")
local sorters = require("vessel.config.sorters")
local util = require("vessel.util")

--- Callback function executed after each jump
---@param mode string
---@param context Context
local function jump_callback(mode, context)
	if string.match(vim.o.jumpoptions, "view") then
		return
	end
	local line = vim.fn.line(".")
	if
		mode == util.modes.BUFFER
		and vim.fn.bufnr("%") == context.bufnr
		and line > context.wininfo.topline
		and line < context.wininfo.botline
	then
		-- Don't center the cursor if we don't jump out of view
		return
	end
	vim.cmd("norm! zz")
end

--- Callback function executed on directory entries
---@param path string
---@param context Context
local function directory_handler(path, context)
	vim.cmd("edit " .. vim.fn.fnameescape(path))
end

--- Filter jump files from being autoloaded
---@param bufnr integer
---@param bufpath string
---@return boolean
local function autoload_filter(bufnr, bufpath)
	return vim.startswith(bufpath, vim.fn.getcwd() .. "/")
end

--- Return the width of the popup
---@return table
local function popup_width()
	return vim.o.columns < 120 and { 90, 90 } or { 75, 90 }
end

--- Default plugin options
return {

	--- generic options
	verbosity = vim.log.levels.INFO,
	lazy_load_buffers = true,
	highlight_on_jump = false,
	highlight_timeout = 250,
	jump_callback = jump_callback,

	--- floating window options
	window = {
		width = popup_width,
		gravity = "center",
		max_height = 75, -- % of the vim ui
		cursorline = true,
		number = false,
		relativenumber = false,
		--- same as :help api-floatwin
		options = {
			style = "minimal",
			border = "single",
		},
	},

	--- preview floating window options
	preview = {
		position = "right",
		min_height = 21, -- lines
		width = 50, -- percentage of the main popup
		width_threshold = 80, -- lines
		options = {
			border = "single",
			style = "minimal",
		},
	},

	-- default commands
	create_commands = false,
	commands = {
		view_marks = "Marks",
		view_jumps = "Jumps",
		view_buffers = "Buffers",
	},

	--- marklist-related options
	marks = {
		preview = true,
		locals = "abcdefghijklmnopqrstuvwxyz",
		globals = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
		sort_marks = { sorters.marks.by_lnum, sorters.marks.by_mark },
		sort_groups = sorters.marks.sort_groups,
		toggle_mark = true,
		use_backtick = false,
		not_found = "No marks found",
		move_to_first_mark = true,
		move_to_closest_mark = true,
		proximity_threshold = 50,
		force_header = false,
		decorations = { "├ ", "└ " },
		show_colnr = false,
		strip_lines = true,
		path_style = "relcwd",
		formatters = {
			mark = marks_formatters.mark_formatter,
			header = marks_formatters.header_formatter,
		},
		highlights = {
			path = "Directory",
			not_loaded = "Comment",
			decorations = "NonText",
			mark = "Keyword",
			lnum = "LineNr",
			col = "LineNr",
			line = "Normal",
		},
		mappings = {
			close = { "q", "<esc>" },
			delete = { "d" },
			next_group = { "<c-j>" },
			prev_group = { "<c-k>" },
			jump = { "l", "<cr>" },
			keepj_jump = { "o" },
			tab = { "t" },
			keepj_tab = { "T" },
			split = { "s" },
			keepj_split = { "S" },
			vsplit = { "v" },
			keepj_vsplit = { "V" },
			cycle_sort = { "<space>" },
		},
	},

	--- jumplist-related options
	jumps = {
		preview = true,
		real_positions = false,
		strip_lines = false,
		filter_empty_lines = true,
		not_found = "Jump list empty",
		indicator = { " ", " " },
		show_colnr = false,
		not_loaded = "",
		autoload_filter = autoload_filter,
		mappings = {
			ctrl_o = "<c-o>",
			ctrl_i = "<c-i>",
			jump = { "l", "<cr>" },
			close = { "q", "<esc>" },
			clear = { "C" },
			load_buffer = { "r" },
			load_all = { "R" },
			load_cwd = { "W" },
		},
		formatters = {
			jump = jumps_formatters.jump_formatter,
		},
		highlights = {
			indicator = "Comment",
			pos = "LineNr",
			current_pos = "CursorLineNr",
			path = "Directory",
			lnum = "LineNr",
			col = "LineNr",
			line = "Normal",
			not_loaded = "Comment",
		},
	},

	--- bufferlist-related options
	buffers = {
		wrap_around = true,
		not_found = "Buffer list empty",
		unnamed_label = "[no name]",
		quickjump = true,
		show_pin_positions = true,
		pin_separator = "─",
		sort_buffers = {
			sorters.buffers.by_path,
			sorters.buffers.by_basename,
			sorters.buffers.by_lastused,
			sorters.buffers.by_changes,
		},
		bufname_align = "left",
		bufname_style = "unique",
		bufpath_style = "relcwd",
		formatter_spacing = " ",
		directory_handler = directory_handler,
		mappings = {
			cycle_sort = { "<space>" },
			pin_increment = { "<c-a>", "<c-j>" },
			pin_decrement = { "<c-x>", "<c-k>" },
			toggle_pin = { "p" },
			add_directory = { "P" },
			toggle_unlisted = { "a" },
			edit = { "l", "<cr>" },
			tab = { "t" },
			split = { "s" },
			vsplit = { "v" },
			delete = { "d" },
			force_delete = { "D" },
			wipe = { "w" },
			force_wipe = { "W" },
			close = { "q", "<esc>" },
		},
		formatters = {
			buffer = buf_formatters.buffer_formatter,
		},
		highlights = {
			bufname = "Normal",
			bufpath = "Comment",
			unlisted = "Comment",
			directory = "Directory",
			modified = "Keyword",
			pin_position = "LineNr",
			pin_separator = "NonText",
		},
	},
}