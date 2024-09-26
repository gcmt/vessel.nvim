---@module "config"

local jumps_formatters = require("vessel.jumplist.formatters")
local marks_formatters = require("vessel.marklist.formatters")
local util = require("vessel.util")

local M = {}

-- Stores anything passed to the setup function
M._opts = {}

--- Load the config by merging the user-provided config and the default config.
---@param opts table?
---@return table
M.load = function(opts)
	M._opts = vim.tbl_deep_extend("force", M.defaults, opts or {})
	return M._opts
end

--- Return the current config, overridden by any options passed as argument
---@param opts table?
---@return table
M.get = function(opts)
	return vim.tbl_deep_extend("force", M._opts, opts or {})
end

--- Compute the 'height' of the popup
--- This function should return an estimate only. This is needed only for correct
--- positioning on the screen. The actual height will adjust to the content later
--- up to the max_height option
---@param list Marklist|Jumplist
---@return integer Number of lines
local function popup_height(list)
	local max_height = list._app.config.window.max_height
	local item_count, group_count = list:get_count()
	local max_lines = item_count + group_count
	local max = math.floor(vim.o.lines * max_height / 100)
	return math.min(max_lines, max)
end

--- Compute the 'width' of the popup window as a percentage of the nvim window
---@return integer
local function popup_width()
	local ui = vim.api.nvim_list_uis()[1]
	return math.floor(ui.width * (ui.width < 120 and 90 or 70) / 100)
end

--- Compute the 'row' position for the popup
---@param width integer The width of the window
---@param height integer The height of the window
---@return integer
local function popup_row(width, height)
	return math.floor((vim.o.lines / 2) - ((height + 2) / 2)) - 1
end

--- Compute the 'col' position for the popup
---@param width integer The width of the window
---@param height integer The height of the window
---@return integer
local function popup_col(width, height)
	local ui = vim.api.nvim_list_uis()[1]
	return math.floor((ui.width / 2) - (width / 2))
end

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

--- Default plugin options
M.defaults = {

	--- generic options
	verbosity = vim.log.levels.INFO,
	lazy_load_buffers = false,
	highlight_on_jump = false,
	highlight_timeout = 250,
	jump_callback = jump_callback,

	--- floating window-related options
	window = {
		max_height = 80, -- % of the vim ui
		cursorline = true,
		number = false,
		relativenumber = false,
		--- same as :help api-floatwin
		options = {
			relative = "editor",
			anchor = "NW",
			style = "minimal",
			border = "single",
			width = popup_width,
			height = popup_height,
			row = popup_row,
			col = popup_col,
		},
	},

	--- marklist-related options
	marks = {
		locals = "abcdefghijklmnopqrstuvwxyz",
		globals = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
		toggle_mark = true,
		use_backtick = false,
		not_found = "No marks found",
		sort_field = "lnum",
		move_to_first_mark = true,
		move_to_closest_mark = true,
		proximity_threshold = 50,
		create_commands = false,
		force_header = false,
		decorations = { "├ ", "└ " },
		show_colnr = false,
		commands = {
			view = "Marks",
			set_local = "Mark",
			set_global = "Markg",
		},
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
			keepj_jump = { "K" },
			tab = { "t" },
			keepj_tab = { "T" },
			split = { "s" },
			keepj_split = { "S" },
			vsplit = { "v" },
			keepj_vsplit = { "V" },
		},
	},

	--- jumplist-related options
	jumps = {
		filter_empty_lines = true,
		not_found = "Jump list empty",
		indicator = { "  > ", "    " },
		show_colnr = false,
		create_commands = false,
		commands = {
			view = "Jumps",
		},
		mappings = {
			jump = { "l", "<cr>" },
			ctrl_o = { "<c-o>" },
			ctrl_i = { "<c-i>" },
			close = { "q", "<esc>" },
			clear = { "C" },
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
		},
	},
}

return M
