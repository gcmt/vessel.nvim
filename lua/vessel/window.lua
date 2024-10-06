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

--- Cap height to not exceed window.max_height
---@param height integer
---@return integer
function Window:_cap_height(height)
	-- take into account statusline and commandline
	local max = math.floor((vim.o.lines - 3) * self.config.window.max_height / 100)
	return math.min(height, max)
end

--- Return default options for the main popup window
---@return table
function Window:_default_opts()
	return vim.tbl_extend("force", self.config.window.options, {
		relative = "editor",
		anchor = "NW",
	})
end

--- Resize the current window height to fit its content,
--- up to max_height % of the total lines
---@return integer
function Window:fit_content()
	local bufinfo = vim.fn.getbufinfo(self.bufnr)[1]
	-- make sure window does not overflow at the bottom
	-- necessary with many unlisted buffers
	local row = vim.fn.getwininfo(self.winid)[1].winrow
	local size = math.min(self:_cap_height(bufinfo.linecount), vim.o.lines - row - 3)
	vim.fn.win_execute(self.winid, "resize " .. size)
	return size
end

--- Compute options for both main and preview window
---@param est_height integer
---@param show_preview boolean
---@return table, table
function Window:_get_popup_options(est_height, show_preview)
	local ui = vim.api.nvim_list_uis()[1]
	local gravity = self.config.window.gravity
	local min_preview_height = self.config.preview.min_height
	local floor = math.floor

	-- main popup options
	local main = self:_default_opts()
	-- preview popup options
	local prev = self.preview:default_opts()

	-- main popup width dependent on screen width
	local width = self.config.window.width
	local p = type(width) == "number" and width or width(show_preview)
	main.width = floor(ui.width * p / 100)

	-- main popup height
	main.height = math.max(self:_cap_height(est_height), 1)

	-- center the main popup horizontally
	main.col = floor((ui.width / 2) - (main.width / 2))

	if self.config.window.gravity == "top" then
		-- move the popup to the top
		local max_height = floor((ui.height - 3) * self.config.window.max_height / 100)
		main.row = floor((ui.height - max_height) / 2) - 1
	elseif self.config.window.gravity == "center" then
		-- center the popup vertically
		main.row = floor((ui.height / 2) - ((main.height + 2) / 2)) - 1
	else
		main.row = 1
	end

	if show_preview then
		-- make preview popup half the total width
		prev.width = floor(main.width * self.config.preview.width / 100)
		-- make space for the preview
		main.width = main.width - prev.width
		-- move preview popup to the right side of the main popup
		prev.col = main.width + 1

		-- align both heights unless the main popup height is < preview.min_height
		prev.height = math.max(min_preview_height, main.height)

		if gravity == "top" then
			-- preview popup will have the top margin aligned to the main popup
			prev.row = -1
			-- consider the tallest window when centering vertically
			main.row = floor((ui.height / 2) - ((prev.height + 2) / 2)) - 1
		elseif gravity == "center" then
			-- center the popups vertically indipendently
			main.row = floor((ui.height / 2) - ((main.height + 2) / 2)) - 1
			prev.row = floor((ui.height / 2) - ((prev.height + 2) / 2)) - 1
			-- set offset (main.row is always >= prev.row)
			prev.row = prev.row - main.row - 1
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
