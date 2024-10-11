---@module "preview"

local util = require("vessel.util")

---@class Preview
---@field config table
---@field buffer_name string
---@field wininfo table
---@field bufnr integer
---@field winid integer
local Preview = {}
Preview.__index = Preview

--- Create new Preview instance
---@param config table
---@return Preview
function Preview:new(config)
	local preview = {}
	setmetatable(preview, Preview)
	preview.buffer_name = "__vessel_preview__"
	preview.config = config
	preview.wininfo = {}
	preview.bufnr = -1
	preview.winid = -1
	return preview
end

--- Create buffer for the preview window
---@return integer
function Preview:_create_buffer()
	local bufnr = vim.fn.bufnr(self.buffer_name)
	if bufnr == -1 then
		bufnr = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(bufnr, self.buffer_name)
	end
	return bufnr
end

--- Return options for the preview window
---@return table
function Preview:default_opts()
	return vim.tbl_extend("force", self.config.preview.options, {
		win = -1,
		relative = "win",
		anchor = "NW",
	})
end

--- Show file content in the preview window
---@param filestore FileStore
---@param path string
---@param lnum integer
---@param filetype string?
function Preview:show(filestore, path, lnum, filetype)
	if self.bufnr == -1 then
		return
	end
	if not path then
		vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
		return
	end
	local lines, err = filestore:getfile(path, true)
	if err then
		vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, { err })
	else
		vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines or {})
		vim.fn.win_execute(self.winid, lnum)
		vim.fn.win_execute(self.winid, "norm! zz")
		if filetype then
			vim.fn.setbufvar(self.bufnr, "&filetype", filetype)
		end
	end
end

--- Clear preview window buffer
function Preview:clear()
	if self.bufnr ~= -1 then
		vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
	end
end

---Setup window options
function Preview:setup_window()
	util.reset_window(self.winid)
	vim.api.nvim_set_option_value("cursorline", true, { win = self.winid })
	vim.api.nvim_set_option_value("number", true, { win = self.winid })
end

--- Open the preview window
---@param opts table Preview window options
---@return integer
function Preview:open(opts)
	self.bufnr = self:_create_buffer()
	self.winid = vim.api.nvim_open_win(self.bufnr, false, opts)
	self.wininfo = vim.fn.getwininfo(self.winid)[1]
	return self.bufnr
end

--- Close the preview window
function Preview:close()
	pcall(vim.fn.win_execute, self.winid, "close")
	pcall(vim.api.nvim_buf_delete, self.bufnr, {})
end

return Preview
