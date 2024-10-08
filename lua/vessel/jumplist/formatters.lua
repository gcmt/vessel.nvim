---@module "formatters"

local util = require("vessel.util")

local M = {}

--- Default formatter for a single jump item
--- Return nil to skip rendering the line
---@param jump Jump The jump entry being formatted
---@param meta table Meta nformation about the jump or other jump entries
---@param context table Information the current buffer/window
---@param config table Configuration
---@return string?, table?
function M.jump_formatter(jump, meta, context, config)
	local indicator = ""
	local hl_pos = ""

	if jump.current then
		indicator = config.jumps.indicator[1]
		hl_pos = config.jumps.highlights.current_pos
	else
		indicator = config.jumps.indicator[2]
		hl_pos = config.jumps.highlights.pos
	end

	local rel_fmt, jump_rel
	if config.jumps.real_position then
		rel_fmt = "%" .. #tostring(meta.max_relpos) .. "s"
		jump_rel = string.format(rel_fmt, math.abs(jump.relpos))
	else
		rel_fmt = "%" .. #tostring(meta.jumps_count) .. "s"
		jump_rel = string.format(rel_fmt, math.abs(meta.current_line - meta.current_jump_line))
	end

	local lnum_fmt = "%" .. #tostring(meta.max_lnum) .. "s"
	local lnum = string.format(lnum_fmt, jump.lnum)

	local col = ""
	if config.jumps.show_colnr then
		local col_fmt = "%" .. #tostring(meta.max_col) .. "s"
		col = "  " .. string.format(col_fmt, jump.col)
	end

	local path_fmt = "%-" .. meta.max_suffix .. "s"
	local path = string.format(path_fmt, meta.suffixes[jump.bufpath])

	local line_hl
	if jump.line then
		if config.jumps.strip_lines then
			jump.line = string.gsub(jump.line, "^%s+", "")
		end
		line_hl = { jump.line, config.jumps.highlights.line }
	else
		if jump.err then
			jump.err = "error: " .. string.gsub(jump.err, "^.*:%s+", "")
		end
		line_hl = {
			jump.err or util.prettify_path(jump.bufpath),
			config.jumps.highlights.not_loaded,
		}
	end

	return util.format(
		"%s%s  %s  %s%s  %s",
		{ indicator, config.jumps.highlights.indicator },
		{ jump_rel, hl_pos },
		{ path, config.jumps.highlights.path },
		{ lnum, config.jumps.highlights.lnum },
		{ col, config.jumps.highlights.col },
		line_hl
	)
end

return M
