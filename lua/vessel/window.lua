---@module "window"

local Preview = require("vessel.preview")
local logger = require("vessel.logger")
local util = require("vessel.util")

---@class Window
---@field buffer_name string
---@field config table
---@field preview Preview
---@field context Context
---@field bufnr integer
---@field winid integer
---@field preview_bufnr integer
---@field preview_winid integer
local Window = {}
Window.__index = Window

--- Create new Window instance
---@param config table
---@param context Context
---@return Window
function Window:new(config, context)
	local win = {}
	setmetatable(win, Window)
	logger.log_level = config.verbosity -- TODO move in each lsit
	win.buffer_name = "__vessel__"
	win.config = config
	win.context = context
	win.preview = Preview:new(config)
	win.bufnr = -1
	win.winid = -1
	win.preview_bufnr = -1
	win.preview_winid = -1
	return win
end

--- Create the window buffer
---@return integer, boolean Whether the buffer was created
function Window:_create_buffer()
	local bufnr = vim.fn.bufnr(self.buffer_name)
	if bufnr == -1 then
		bufnr = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(bufnr, self.buffer_name)
		return bufnr, true
	end
	return bufnr, false
end

--- Close the window
function Window:_close_window()
	self.preview:close()
	pcall(vim.api.nvim_buf_delete, self.bufnr, {})
	pcall(vim.cmd, self.context.wininfo.winnr .. "wincmd w")
	pcall(vim.fn.win_execute, self.winid, "close")
end

--- Setup the buffer by setting sensible options
---@param winid integer
function Window:_setup_window(winid)
	util.reset_window(winid)
	local wininfo = vim.fn.getwininfo(winid)
	local bufnr = wininfo[1].bufnr
	local winnr = wininfo[1].winnr
	vim.fn.setwinvar(winnr, "&cursorline", self.config.window.cursorline)
	vim.fn.setwinvar(winnr, "&number", self.config.window.number)
	vim.fn.setwinvar(winnr, "&relativenumber", self.config.window.relativenumber)
	vim.api.nvim_create_autocmd("BufLeave", {
		desc = "Close the window when switching to another buffer",
		buffer = bufnr,
		callback = function()
			self:_close_window()
		end,
		once = true,
	})
end

--- Set the buffer-local variable with info about the buffer content
---@param map table
function Window:_set_buffer_data(map)
	vim.api.nvim_buf_set_var(self.bufnr, "vessel", {
		map = map,
		get_selected = function()
			return map[vim.fn.line(".")]
		end,
		close_window = function()
			self:_close_window()
		end,
	})
end

--- Compute the 'height' of the main popup window
--- This function returns an estimate only. This is needed only for correct
--- positioning on the screen. The actual height will adjust to the content later
--- up to the max_height option
---@param est_height integer Estimated height
---@return integer Number of lines
function Window:_popup_height(est_height)
	local max = math.floor(vim.o.lines - 2 * self.config.window.max_height / 100)
	return math.max(math.min(est_height, max), 1)
end

--- Compute the 'width' of the main popup window
---@param show_preview boolean Whether the preview popup window is enabled
---@return integer
function Window:_popup_width(show_preview)
	local percentage
	local ui = vim.api.nvim_list_uis()[1]
	if show_preview then
		-- use 90% of the wisth to accomodate the popup
		percentage = 90
	else
		percentage = ui.width < 120 and 90 or 70
	end
	return math.floor(ui.width * percentage / 100)
end

--- Compute the 'row' position for the popup
---@param height integer The height of the popup window
---@return integer
function Window:_popup_row(height)
	if self.config.window.gravity == "top" then
		-- move the popup to the top
		local max_height = math.floor(vim.o.lines * self.config.window.max_height / 100)
		return math.floor((vim.o.lines - max_height) / 2) - 1
	elseif self.config.window.gravity == "center" then
		-- center the popup vertically
		return math.floor((vim.o.lines / 2) - ((height + 2) / 2)) - 1
	end
	return 1
end

--- Compute the 'col' position for the popup
---@param width integer The width of the popup window
---@return integer
function Window:_popup_col(width)
	-- Center the popup horizontally
	local ui = vim.api.nvim_list_uis()[1]
	return math.floor((ui.width / 2) - (width / 2))
end

--- Return default options for the main popup window
---@return table
function Window:_default_opts()
	return vim.tbl_extend("force", self.config.window.options, {
		relative = "editor",
		anchor = "NW",
	})
end

--- Compute options for both main and preview window
---@param est_height integer
---@param show_preview boolean
---@return table, table
function Window:_get_popup_options(est_height, show_preview)
	local main = self:_default_opts()
	local prev = self.preview:default_opts()

	main.width = self:_popup_width(show_preview)
	main.height = self:_popup_height(est_height)
	main.row = self:_popup_row(main.height)
	main.col = self:_popup_col(main.width)

	if show_preview then
		local lines = vim.o.lines
		local gravity = self.config.window.gravity
		local preview_gravity = self.config.window.preview_gravity
		local min_preview_height = self.config.window.min_preview_height

		-- make preview popup half the total width
		prev.width = math.floor(main.width * 50 / 100)
		-- make space for the preview
		main.width = main.width - prev.width
		-- move preview popup to the right side of the main popup
		prev.col = main.width + 1

		if preview_gravity == "none" then
			-- preview popup will span the whole height
			prev.height = lines - 4
			prev.row = -main.row - 1
		elseif preview_gravity == "center" then
			-- align both heights unless the main popup height is < min_preview_height
			prev.height = math.max(min_preview_height, main.height)
			if gravity == "top" then
				-- preview popup will have the top margin aligned to the main popup
				prev.row = -1
				-- consider the tallest window when centering vertically
				-- main.row = math.floor((lines / 2) - ((math.max(main.height, prev.height) + 2) / 2))
				-- - 1
				main.row = math.floor((lines / 2) - ((prev.height + 2) / 2)) - 1
			elseif gravity == "center" then
				-- venter the popups vertically indipendently
				main.row = math.floor((lines / 2) - ((main.height + 2) / 2)) - 1
				prev.row = math.floor((lines / 2) - ((prev.height + 2) / 2)) - 1
				-- set offset (main.row is always >= prev.row)
				prev.row = prev.row - main.row - 1
				print(
					"main height =",
					main.height,
					"prev height =",
					prev.height,
					"main row =",
					main.row,
					"prev.row",
					prev.row
				)
			end
		end
	end

	return main, prev
end

--- Open the floating window
---@param est_height integer For centering the window
---@param show_preview boolean Whether to also open the preview window
---@return integer, boolean
function Window:open(est_height, show_preview)
	local main_opts, prev_opts = self:_get_popup_options(est_height, show_preview)

	self.bufnr = self:_create_buffer()
	if vim.fn.bufwinid(self.bufnr) == -1 then
		self.winid = vim.api.nvim_open_win(self.bufnr, true, main_opts)
		self:_setup_window(self.winid)
	else
		logger.warn("window already open")
		return self.bufnr, false
	end

	if show_preview then
		prev_opts.win = self.winid
		self.preview:open(prev_opts)
	end

	return self.bufnr, true
end

return Window
