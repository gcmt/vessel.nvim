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
	if config.buffers.bufname_align == "right" then
		align = "%"
	elseif config.buffers.bufname_align == "left" then
		align = "%-"
	end
	local name = ""
	local bname_fmt = "%s"
	if config.buffers.bufname_style == "unique" then
		name = meta.suffixes[path]
		bname_fmt = align .. meta.max_suffix .. "s"
	elseif config.buffers.bufname_style == "basename" then
		name = vim.fs.basename(path)
		bname_fmt = align .. meta.max_basename .. "s"
	elseif config.buffers.bufname_style == "hide" then
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
	if config.buffers.bufpath_style == "relcwd" then
		return util.prettify_path(path)
	elseif config.buffers.bufpath_style == "relhome" then
		return select(1, string.gsub(path, "^" .. os.getenv("HOME") .. "/", "~/", 1))
	elseif config.buffers.bufpath_style == "short" then
		return meta.suffixes[path]
	elseif config.buffers.bufpath_style == "full" then
		return path
	elseif config.buffers.bufpath_style == "hide" then
		return ""
	end
	return ""
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

	local pinned_pos = ""
	if meta.pinned_count > 0 and config.buffers.show_pin_positions then
		local pos_fmt = "%" .. #tostring(meta.pinned_count) .. "s"
		if buffer.pinpos > 0 then
			pinned_pos = string.format(pos_fmt, buffer.pinpos)
		else
			pinned_pos = string.format(pos_fmt, " ")
		end
	end

	pinned_pos = pinned_pos ~= "" and pinned_pos .. config.buffers.formatter_spacing or ""
	bufname = bufname ~= "" and bufname .. config.buffers.formatter_spacing or ""

	local hl_bufname = config.buffers.highlights.bufname
	if vim.fn.buflisted(buffer.nr) == 0 then
		hl_bufname = config.buffers.highlights.unlisted
	elseif vim.fn.isdirectory(buffer.path) == 1 then
		hl_bufname = config.buffers.highlights.directory
	elseif vim.fn.getbufvar(buffer.nr, "&modified") == 1 then
		hl_bufname = config.buffers.highlights.modified
	end

	return util.format(
		" %s%s%s",
		{ pinned_pos, config.buffers.highlights.pin_position },
		{ bufname, hl_bufname },
		{ bufpath, config.buffers.highlights.bufpath }
	)
end

return M
