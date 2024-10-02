---@module "formatters"

local util = require("vessel.util")

local M = {}

--- Default formatter for a single buffer entry
---@param buffer Buffer The buffer entry being formatted
---@param meta table Meta nformation about the buffer or other buffer entries
---@param context table Information the current buffer/window
---@param config table Configuration
---@return string?, table?
function M.buffer_formatter(buffer, meta, context, config)
	local bufname, bufpath
	if buffer.path == "" then
		bufname = config.buffers.unnamed_label
		bufpath = buffer.nr
	else
		bufname = meta.suffixes[buffer.path]
		bufpath = util.prettify_path(buffer.path)
	end
	local hl_bufname = config.buffers.highlights.bufname
	if vim.fn.isdirectory(buffer.path) == 1 then
		hl_bufname = config.buffers.highlights.directory
	end
	if vim.fn.getbufvar(buffer.nr, "&modified") == 1 then
		hl_bufname = config.buffers.highlights.modified
	end
	if vim.fn.buflisted(buffer.nr) == 0 then
		hl_bufname = config.buffers.highlights.unlisted
	end
	return util.format(
		" %s %s",
		{ bufname, hl_bufname },
		{ bufpath, config.buffers.highlights.bufpath }
	)
end

return M
