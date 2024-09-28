---@module "config"

local jumps_formatters = require("vessel.jumplist.formatters")
local marks_formatters = require("vessel.marklist.formatters")
local config_proxy = require("vessel.config.proxy")
local schema = require("vessel.config.schema")
local util = require("vessel.util")
local logger = require("vessel.logger")
local validate = require("vessel.config.validate")

local M = {}

--- Function used to sort marks
---@param a Mark
---@param b Mark
---@return boolean
local function sort_marks(a, b)
	return a.lnum < b.lnum
end

--- Function used to sort mark groups
---@param a string Path
---@param b string Path
---@return boolean
local function sort_groups(a, b)
	return a > b
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
local _opt = {

	--- generic options
	verbosity = vim.log.levels.INFO,
	lazy_load_buffers = true,
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

	-- default commands
	create_commands = false,
	commands = {
		view_marks = "Marks",
		view_jumps = "Jumps",
	},

	--- marklist-related options
	marks = {
		locals = "abcdefghijklmnopqrstuvwxyz",
		globals = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
		sort_marks = sort_marks,
		sort_groups = sort_groups,
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
		},
	},

	--- jumplist-related options
	jumps = {
		rel_virtual = true,
		strip_lines = false,
		filter_empty_lines = true,
		not_found = "Jump list empty",
		indicator = { "  > ", "    " },
		show_colnr = false,
		ctrl_o = "<c-o>",
		ctrl_i = "<c-i>",
		mappings = {
			jump = { "l", "<cr>" },
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

--- Validate the given options
---@param opts table?
---@return boolean
local function check_options(opts)
	local ok, err = pcall(validate.validate_partial, opts or {}, schema)
	if not ok then
		local msg = string.gsub(tostring(err), "^.-:%d+:%s+", "")
		logger.err("option validation error: %s", msg)
		return false
	end
	return true
end

--- Load the config by merging the user-provided config and the default config.
---@param opts table?
---@return table
M.load = function(opts)
	if check_options(opts) then
		_opt = vim.tbl_deep_extend("force", _opt, opts or {})
		M.opt = config_proxy.new(_opt, check_options)
	end
	return _opt
end

--- Return the current config, overridden by any options passed as argument
---@param opts table?
---@return table
M.get = function(opts)
	if check_options(opts) then
		return vim.tbl_deep_extend("force", _opt, opts or {})
	end
	return _opt
end

--- Proxy object to allow setting options safely
M.opt = config_proxy.new(_opt, check_options)

return M
