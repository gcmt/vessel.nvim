---@module "window"

local Preview = require("vessel.preview")
local logger = require("vessel.logger")
local schema = require("vessel.config.schema")
local util = require("vessel.util")

---@class Window
---@field buffer_name string
---@field config table
---@field preview Preview
---@field context Context
---@field bufnr integer
---@field winid integer
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
function Window:_setup_window()
	util.reset_window(self.winid)
	local wininfo = vim.fn.getwininfo(self.winid)
	local winnr = wininfo[1].winnr
	vim.fn.setwinvar(winnr, "&cursorline", self.config.window.cursorline)
	vim.fn.setwinvar(winnr, "&number", self.config.window.number)
	vim.fn.setwinvar(winnr, "&relativenumber", self.config.window.relativenumber)
	if vim.fn.exists("&winfixbuf") == 1 then
		vim.fn.setwinvar(winnr, "&winfixbuf", 1)
	end
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
function Window:fit_content()
	local has_preview = self.preview.winid ~= -1
	local bufinfo = vim.fn.getbufinfo(self.bufnr)[1]
	local main_opts, prev_opts = self:_get_popup_options(bufinfo.linecount, has_preview)
	vim.api.nvim_win_set_config(self.winid, main_opts)
	self:_setup_window()
	if has_preview then
		vim.api.nvim_win_set_config(self.preview.winid, prev_opts)
		self.preview:setup_window()
	end
end

--- Compute options for both main and preview window
---@param height integer
---@param show_preview boolean
---@return table, table
function Window:_get_popup_options(height, show_preview)
	local ui = vim.api.nvim_list_uis()[1]
	local gravity = self.config.window.gravity
	local min_preview_height = self.config.preview.min_height
	local preview_pos = self.config.preview.position
	local floor = math.floor
	local min = math.min
	local max = math.max

	-- main popup options
	local main = self:_default_opts()
	-- preview popup options
	local prev = self.preview:default_opts()

	local ok, width
	if type(self.config.window.width) == "function" then
		ok, width = pcall(self.config.window.width)
		if not ok then
			local msg = string.gsub(tostring(width), "^.-:%d+:%s+", "")
			error("validation error: window.width: " .. msg)
		end
	else
		width = self.config.window.width
	end
	local check, msg = unpack(schema.__listof("number", false, 2))
	if not check(width) then
		error("validation error: window.width: expected " .. msg)
	end

	local p1, p2 = unpack(width)
	main.width = floor(ui.width * p1 / 100)

	if show_preview and preview_pos == "right" then
		main.width = floor(ui.width * p2 / 100)
		local threshold = self.config.preview.width_threshold
		-- move preview window at the bottom if main popup width < threshold
		if (main.width * (100 - self.config.preview.width) / 100) < threshold then
			preview_pos = "bottom"
			main.width = floor(ui.width * p1 / 100)
		end
	end

	-- main popup height
	main.height = max(self:_cap_height(height), 1)

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
		if preview_pos == "right" then
			-- make preview popup half the total width
			prev.width = floor(main.width * self.config.preview.width / 100)
			-- make space for the preview
			main.width = main.width - prev.width
			-- move preview popup to the right side of the main popup
			prev.col = main.width + 1

			-- align both heights unless the main popup height is < preview.min_height
			prev.height = max(min_preview_height, main.height)

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
		else
			-- move popup at the bottom
			prev.width = main.width
			main.height = main.height
			prev.height = min_preview_height
			-- compute max available height for both popups combined
			local max_height = self:_cap_height(main.height + prev.height)
			-- center popup vertically in the screen
			main.row = floor(((ui.height - 2) / 2) - ((max_height + 4) / 2))
			-- make sure main popop takes at leat 50% of available space
			main.height = min(main.height, floor(max_height * 50 / 100))
			prev.height = max_height - main.height
			prev.row = main.height + 1
			prev.col = -1
		end
	end

	prev.win = self.winid
	return main, prev
end

--- Open the floating window
---@param height integer For centering the window
---@param show_preview boolean Whether to also open the preview window
---@return integer, boolean
function Window:open(height, show_preview)
	if height == 0 then
		show_preview = false
	end

	local main_opts, prev_opts = self:_get_popup_options(height, show_preview)

	self.bufnr = self:_create_buffer()
	if vim.fn.bufwinid(self.bufnr) == -1 then
		self.winid = vim.api.nvim_open_win(self.bufnr, true, main_opts)
		self:_setup_window()
	else
		logger.warn("window already open")
		return self.bufnr, false
	end

	if show_preview then
		self.preview:open(prev_opts)
	end

	return self.bufnr, true
end

return Window
