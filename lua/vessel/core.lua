---@module "core"

local Context = require("vessel.context")
local Logger = require("vessel.logger")

---@class App
---@field buffer_name string
---@field config table
---@field context Context
---@field bufnr integer
---@field winid integer?
---@field logger Logger
local App = {}
App.__index = App

--- Create new App instance
---@param config table
---@return App
function App:new(config)
	local app = {}
	setmetatable(app, App)
	app.buffer_name = "__vessel__"
	app.config = config
	app.context = Context:new()
	app.logger = Logger:new(config.verbosity)
	app.logger:set_prefixes({ err = "vessel: "})
	app.bufnr = -1
	app.winid = -1
	return app
end

--- Create the window buffer
---@return integer, boolean Whether the buffer was created
function App:_create_buffer()
	local bufnr = vim.fn.bufnr(self.buffer_name)
	if bufnr == -1 then
		bufnr = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(bufnr, self.buffer_name)
		return bufnr, true
	end
	return bufnr, false
end

--- Close the window
function App:_close_window()
	vim.fn.win_execute(self.winid, "close")
	vim.api.nvim_set_current_win(self.context.wininfo.winid)
end

--- Setup the buffer by setting sensible options
---@param winid integer
function App:_setup_window(winid)
	local wininfo = vim.fn.getwininfo(winid)
	local bufnr = wininfo[1].bufnr
	local winnr = wininfo[1].winnr

	vim.fn.setbufvar(bufnr, "&buftype", "nofile")
	vim.fn.setbufvar(bufnr, "&bufhidden", "delete")
	vim.fn.setbufvar(bufnr, "&buflisted", 0)
	vim.fn.setwinvar(winnr, "&cursorcolumn", 0)
	vim.fn.setwinvar(winnr, "&colorcolumn", 0)
	vim.fn.setwinvar(winnr, "&signcolumn", "no")
	vim.fn.setwinvar(winnr, "&wrap", 0)
	vim.fn.setwinvar(winnr, "&list", 0)
	vim.fn.setwinvar(winnr, "&textwidth", 0)
	vim.fn.setwinvar(winnr, "&undofile", 0)
	vim.fn.setwinvar(winnr, "&backup", 0)
	vim.fn.setwinvar(winnr, "&swapfile", 0)
	vim.fn.setwinvar(winnr, "&spell", 0)
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

--- Return options for the popup window
--- Compute width|height|col|row at runtime if they are defined as functions
---@param list Marklist|Jumplist (Must have get_count() method)
---@return table
function App:_get_popup_options(list)
	local opts = {}
	for key, val in pairs(self.config.window.options) do
		opts[key] = val
	end

	local get = function(field, ...)
		if type(opts[field]) == "function" then
			return opts[field](...)
		end
		return opts[field]
	end

	opts.width = get("width")
	opts.height = get("height", list)
	opts.row = get("row", opts.width, opts.height)
	opts.col = get("col", opts.width, opts.height)

	if opts.height == 0 then
		opts.height = 1
	end

	return opts
end

--- Open the popup window
---@param list Marklist|Jumplist
---@return integer, boolean Whether the window was actually opened
function App:open_window(list)
	local popup_opts = self:_get_popup_options(list)
	self.bufnr = self:_create_buffer()
	if vim.fn.bufwinid(self.bufnr) == -1 then
		self.winid = vim.api.nvim_open_win(self.bufnr, true, popup_opts)
		self:_setup_window(self.winid)
	else
		self.logger:warn("window already open")
		return self.bufnr, false
	end
	return self.bufnr, true
end

return App
