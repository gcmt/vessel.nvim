---@module "preview"

local util = require("vessel.util")

---@class Preview
---@field config table
---@field buffer_name string
---@field wininfo table
---@field bufnr integer
---@field winid integer
---@field _cache table
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
	preview._cache = {}
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

--- Return a function that can be used to read files into the preview buffer.
---
--- `max_lnums' maps each path to the max jump line inside that file.
--- This is useful for optimizing the amount of lines read for each file.
---
---@param max_lnums table
---@return function
function Preview:make_writer(max_lnums)
	return function(path, lnum)
		if not path then
			vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
			return
		end
		local lines
		if self._cache[path] then
			lines = self._cache[path]
		else
			if vim.fn.bufloaded(path) == 1 then
				lines = vim.fn.getbufline(path, 1, "$")
			else
				local max_lnum = (max_lnums[path] or 1) + (self.wininfo.height * 2)
				if vim.fn.filereadable(path) == 1 then
					lines = vim.fn.readfile(path, max_lnum)
				else
					lines = { "File does not exist: " .. path }
				end
				self._cache[path] = lines
			end
		end
		vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
		vim.fn.win_execute(self.winid, lnum)
		vim.fn.win_execute(self.winid, "norm! zz")
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
