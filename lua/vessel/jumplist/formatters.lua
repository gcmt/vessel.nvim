---@module "formatters"

local util = require("vessel.util")

local M = {}

--- Default formatter for a single jump item
--- Return nil to skip rendering the line
---@param ctx table
---@param config table
---@return string?, table?
function M.jump_formatter(ctx, config)
	local indicator = ""
	local hl_pos = ""

	if ctx.jump.pos == ctx.current_pos then
		indicator = config.jumps.indicator[1]
		hl_pos = config.jumps.highlights.current_pos
	else
		indicator = config.jumps.indicator[2]
		hl_pos = config.jumps.highlights.pos
	end

	local rel_fmt = "%" .. #tostring(ctx.max_rel) .. "s"
	local jump_rel = string.format(rel_fmt, math.abs(ctx.jump.rel))

	local lnum_fmt = "%" .. #tostring(ctx.max_lnum) .. "s"
	local lnum = string.format(lnum_fmt, ctx.jump.lnum)

	local col = ""
	if config.jumps.show_colnr then
		local col_fmt = "%" .. #tostring(ctx.max_col) .. "s"
		col = "  " .. string.format(col_fmt, ctx.jump.col)
	end

	local path_fmt = "%-" .. ctx.max_unique .. "s"
	local path = string.format(path_fmt, ctx.uniques[ctx.jump.bufpath])

	local line = ctx.jump.line
	if config.jumps.strip_lines then
		line = string.gsub(line, "^%s+", "")
	end

	return util.format(
		"%s%s  %s  %s%s  %s",
		{ indicator, config.jumps.highlights.indicator },
		{ jump_rel, hl_pos },
		{ path, config.jumps.highlights.path },
		{ lnum, config.jumps.highlights.lnum },
		{ col, config.jumps.highlights.col },
		{ line, config.jumps.highlights.line }
	)
end

return M
