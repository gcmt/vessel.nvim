---@module "formatters"

local util = require("vessel.util")

local M = {}

--- Return line prefix
---@param mark Mark The mark entry being formatted
---@param meta table Information about the mark or other mark entries
---@param context table Information the current buffer/window
---@param config table Configuration
---@return string
local function get_prefix(mark, meta, context, config)
	if
		meta.groups_count == 1
		and not config.marks.force_header
		and mark.file == context.bufpath
	then
		return " "
	end
	local decorations = config.marks.decorations
	if decorations and #decorations == 2 then
		return meta.is_last and decorations[2] or decorations[1]
	end
	return ""
end

--- Default formatter for a single mark line
--- Return nil to skip rendering the line
---@param mark Mark The mark entry being formatted
---@param meta table Information about the mark or other mark entries
---@param context table Information the current buffer/window
---@param config table Configuration
---@return string?, table?
function M.mark_formatter(mark, meta, context, config)
	local prefix = get_prefix(mark, meta, context, config)

	local lnum_fmt = "%" .. #tostring(meta.max_group_lnum) .. "s"
	local lnum = string.format(lnum_fmt, mark.lnum)

	local col = ""
	if config.marks.show_colnr then
		local col_fmt = "%" .. #tostring(meta.max_group_col) .. "s"
		col = " " .. string.format(col_fmt, mark.col)
	end

	local line = mark.line
	if config.marks.strip_lines then
		line = string.gsub(line, "^%s+", "")
	end
	local line_hl = { line, config.marks.highlights.line }
	if not mark.loaded then
		line = util.prettify_path(mark.file)
		line_hl = { line, config.marks.highlights.not_loaded }
	end

	return util.format(
		" %s%s  %s%s  %s",
		{ prefix, config.marks.highlights.decorations },
		{ mark.mark, config.marks.highlights.mark },
		{ lnum, config.marks.highlights.lnum },
		{ col, config.marks.highlights.col },
		line_hl
	)
end

--- Default formatter for a group header line (mark file path)
--- Return nil to skip rendering the line
---@param path string The header file path
---@param meta table Information about marks in the group or other groups
---@param context table Information the current buffer/window
---@param config table Configuration
---@return string?, table?
function M.header_formatter(path, meta, context, config)
	if meta.groups_count == 1 and not config.marks.force_header and path == context.bufpath then
		return nil
	end
	if config.marks.path_style == "relcwd" then
		path = util.prettify_path(path)
	elseif config.marks.path_style == "relhome" then
		path = string.gsub(path, "^" .. os.getenv("HOME") .. "/", "~/", 1)
	elseif config.marks.path_style == "short" then
		path = meta.suffixes[path]
	else
		path = path
	end
	return util.format(" %s", { path, config.marks.highlights.path })
end

return M
