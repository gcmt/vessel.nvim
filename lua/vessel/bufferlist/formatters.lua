---@module "formatters"

local util = require("vessel.util")

local M = {}

--- Format the given path according to user preferences
---@param path string
---@param meta table
---@param config table
---@return string
local function format_bufname(path, meta, config)
	local align = ""
	if config.buffers.name_align == "right" then
		align = "%"
	elseif config.buffers.name_align == "left" then
		align = "%-"
	end
	local name = ""
	local bname_fmt = "%s"
	if config.buffers.name_style == "unique" then
		name = meta.suffixes[path]
		bname_fmt = align .. meta.max_suffix .. "s"
	elseif config.buffers.name_style == "basename" then
		name = vim.fs.basename(path)
		bname_fmt = align .. meta.max_basename .. "s"
	elseif config.buffers.name_style == "hide" then
		name = ""
	end
	if align ~= "" and name ~= "" then
		return string.format(bname_fmt, name)
	else
		return name
	end
end

--- Format the given path according to user preferences
---@param path string
---@param meta table
---@param config table
---@return string
local function format_path(path, meta, config)
	if config.buffers.path_style == "relcwd" then
		return util.prettify_path(path)
	elseif config.buffers.path_style == "relhome" then
		return select(1, string.gsub(path, "^" .. os.getenv("HOME") .. "/", "~/", 1))
	elseif config.buffers.path_style == "short" then
		return meta.suffixes[path]
	elseif config.buffers.path_style == "full" then
		return path
	elseif config.buffers.path_style == "hide" then
		return ""
	end
end

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
		bufname = format_bufname(buffer.path, meta, config)
		bufpath = format_path(buffer.path, meta, config)
	end

	bufname = bufname ~= "" and " " .. bufname or ""
	bufpath = bufpath ~= "" and " " .. bufpath or ""

	local hl_bufname = config.buffers.highlights.bufname
	if vim.fn.isdirectory(buffer.path) == 1 then
		hl_bufname = config.buffers.highlights.directory
	elseif vim.fn.getbufvar(buffer.nr, "&modified") == 1 then
		hl_bufname = config.buffers.highlights.modified
	elseif vim.fn.buflisted(buffer.nr) == 0 then
		hl_bufname = config.buffers.highlights.unlisted
	end

	return util.format(
		"%s%s",
		{ bufname, hl_bufname },
		{ bufpath, config.buffers.highlights.bufpath }
	)
end

return M
