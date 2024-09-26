---@module "formatters"

local util = require("vessel.util")

local M = {}

--- Return line prefix
---@param ctx table
---@param config table
---@return string
local function get_prefix(ctx, config)
	if ctx.groups_count == 1 and not config.marks.force_header and ctx.mark.file == ctx.cur_bufpath then
		return " "
	end
	local decorations = config.marks.decorations
	if decorations and #decorations == 2 then
		return ctx.is_last and decorations[2] or decorations[1]
	end
	return ""
end

--- Default formatter for a single mark line
--- Return nil to skip rendering the line
---@param ctx table
---@param config table
---@return string?, table?
function M.mark_formatter(ctx, config)
	local prefix = get_prefix(ctx, config)
	local line = string.gsub(ctx.mark.line, "^%s+", "")

	local lnum_fmt = "%" .. #tostring(ctx.max_group_lnum) .. "s"
	local lnum = string.format(lnum_fmt, ctx.mark.lnum)

	local col = ""
	if config.marks.show_colnr then
		local col_fmt = "%" .. #tostring(ctx.max_group_col) .. "s"
		col = " " .. string.format(col_fmt, ctx.mark.col)
	end

	local line_hl = { line, config.marks.highlights.line }
	if not ctx.mark.loaded then
		line = util.prettify_path(ctx.mark.file)
		line_hl = { line, config.marks.highlights.not_loaded }
	end

	return util.format(
		"%s%s  %s%s  %s",
		{ prefix, config.marks.highlights.decorations },
		{ ctx.mark.mark, config.marks.highlights.mark },
		{ lnum, config.marks.highlights.lnum },
		{ col, config.marks.highlights.col },
		line_hl
	)
end

--- Default formatter for a group header line (mark file path)
--- Return nil to skip rendering the line
---@param ctx table
---@param config table
---@return string?, table?
function M.header_formatter(ctx, config)
	if ctx.groups_count == 1 and not config.marks.force_header and ctx.file == ctx.cur_bufpath then
		return nil
	end
	return util.format("%s", { util.prettify_path(ctx.file), config.marks.highlights.path })
end

return M
