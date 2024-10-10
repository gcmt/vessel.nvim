---@module "schema"

local logger = require("vessel.logger")
local util = require("vessel.util")

--- Check if a list contains only values of the given type
---@param typ string
---@param len integer?
---@return table
local function listof(typ, allow_empty, len)
	local qty = len and " " .. len or ""
	local s = len == 1 and "" or "s"
	local msg = string.format("list of%s %s%s", qty, typ, s)
	if allow_empty ~= nil and not allow_empty then
		msg = msg .. " (non-empty)"
	end
	local fn = function(t)
		if type(t) ~= "table" then
			return false
		end
		local count = 0
		for _, v in pairs(t) do
			if type(v) ~= typ then
				return false
			end
			count = count + 1
		end
		if len and len ~= count then
			return false
		end
		if allow_empty ~= nil and not allow_empty and count == 0 then
			return false
		end
		return true
	end
	return { fn, msg }
end

--- Check if a value is in the choices table
---@param ... any
---@return table
local function oneof(...)
	local t = { ... }
	local msg = "one of " .. util.join("|", ...)
	local fn = function(val)
		for _, v in pairs(t) do
			if v == val then
				return true
			end
		end
		return false
	end
	return { fn, msg }
end

--- Pass validation but give message about deprecation
local function deprecated(option)
	return {
		function(_)
			logger.warn("option is deprecated: '%s' (see :help vessel-changelog)", option)
			return true
		end,
	}
end

return {

	__listof = listof,
	__oneof = oneof,

	["verbosity"] = oneof(0, 1, 2, 3, 4, 5),
	["lazy_load_buffers"] = deprecated("lazy_load_buffers"),
	["highlight_on_jump"] = { "boolean" },
	["highlight_timeout"] = { "number" },
	["jump_callback"] = { "function" },

	["window"] = { "table" },
	["window.width"] = { "table", "function" },
	["window.gravity"] = oneof("center", "top"),
	["window.max_height"] = { "number" },
	["window.cursorline"] = { "boolean" },
	["window.number"] = { "boolean" },
	["window.relativenumber"] = { "boolean" },

	["window.options"] = { "table" },
	["window.options.style"] = { "string" },
	["window.options.border"] = { "string" },

	["preview"] = { "table" },
	["preview.position"] = oneof("right", "bottom"),
	["preview.width"] = { "number" },
	["preview.width_threshold"] = { "number" },
	["preview.min_height"] = { "number" },

	["preview.options"] = { "table" },
	["preview.options.style"] = { "string" },
	["preview.options.border"] = { "string" },

	["create_commands"] = { "boolean" },

	["commands"] = { "table" },
	["commands.view_marks"] = { "string" },
	["commands.view_jumps"] = { "string" },
	["commands.view_buffers"] = { "string" },

	["marks"] = { "table" },
	["marks.preview"] = { "boolean" },
	["marks.locals"] = { "string" },
	["marks.globals"] = { "string" },
	["marks.sort_marks"] = listof("function", false),
	["marks.sort_groups"] = "function",
	["marks.toggle_mark"] = { "boolean" },
	["marks.use_backtick"] = { "boolean" },
	["marks.not_found"] = { "string" },
	["marks.move_to_first_mark"] = { "boolean" },
	["marks.move_to_closest_mark"] = { "boolean" },
	["marks.proximity_threshold"] = { "number" },
	["marks.force_header"] = { "boolean" },
	["marks.decorations"] = listof("string", false, 2),
	["marks.show_colnr"] = { "boolean" },
	["marks.strip_lines"] = { "boolean" },
	["marks.path_style"] = oneof("full", "short", "relhome", "relcwd"),

	["marks.formatters"] = { "table" },
	["marks.formatters.mark"] = { "function" },
	["marks.formatters.header"] = { "function" },

	["marks.highlights"] = { "table" },
	["marks.highlights.path"] = { "string" },
	["marks.highlights.not_loaded"] = { "string" },
	["marks.highlights.decorations"] = { "string" },
	["marks.highlights.mark"] = { "string" },
	["marks.highlights.lnum"] = { "string" },
	["marks.highlights.col"] = { "string" },
	["marks.highlights.line"] = { "string" },

	["marks.mappings"] = { "table" },
	["marks.mappings.close"] = listof("string"),
	["marks.mappings.delete"] = listof("string"),
	["marks.mappings.next_group"] = listof("string"),
	["marks.mappings.prev_group"] = listof("string"),
	["marks.mappings.jump"] = listof("string"),
	["marks.mappings.keepj_jump"] = listof("string"),
	["marks.mappings.tab"] = listof("string"),
	["marks.mappings.keepj_tab"] = listof("string"),
	["marks.mappings.split"] = listof("string"),
	["marks.mappings.keepj_split"] = listof("string"),
	["marks.mappings.vsplit"] = listof("string"),
	["marks.mappings.keepj_vsplit"] = listof("string"),

	["jumps"] = { "table" },
	["jumps.preview"] = { "boolean" },
	["jumps.real_positions"] = { "boolean" },
	["jumps.strip_lines"] = { "boolean" },
	["jumps.filter_empty_lines"] = { "boolean" },
	["jumps.not_found"] = { "string" },
	["jumps.not_loaded"] = deprecated("jumps.not_loaded"),
	["jumps.indicator"] = listof("string", false, 2),
	["jumps.show_colnr"] = { "boolean" },
	["jumps.autoload_filter"] = deprecated("jumps.autoload_filter"),

	["jumps.mappings"] = { "table" },
	["jumps.mappings.ctrl_o"] = { "string" },
	["jumps.mappings.ctrl_i"] = { "string" },
	["jumps.mappings.jump"] = listof("string"),
	["jumps.mappings.close"] = listof("string"),
	["jumps.mappings.clear"] = listof("string"),
	["jumps.mappings.load_buffer"] = deprecated("jumps.mappings.load_buffer"),
	["jumps.mappings.load_all"] = deprecated("jumps.mappings.load_all"),
	["jumps.mappings.load_cwd"] = deprecated("jumps.mappings.load_cwd"),

	["jumps.formatters"] = { "table" },
	["jumps.formatters.jump"] = { "function" },

	["jumps.highlights"] = { "table" },
	["jumps.highlights.indicator"] = { "string" },
	["jumps.highlights.pos"] = { "string" },
	["jumps.highlights.current_pos"] = { "string" },
	["jumps.highlights.path"] = { "string" },
	["jumps.highlights.lnum"] = { "string" },
	["jumps.highlights.col"] = { "string" },
	["jumps.highlights.line"] = { "string" },
	["jumps.highlights.not_loaded"] = { "string" },

	["buffers"] = { "table" },
	["buffers.view"] = oneof("flat", "tree"),
	["buffers.wrap_around"] = { "boolean" },
	["buffers.not_found"] = { "string" },
	["buffers.unnamed_label"] = { "string" },
	["buffers.quickjump"] = { "boolean" },
	["buffers.show_pin_positions"] = { "boolean" },
	["buffers.pin_separator"] = { "string" },
	["buffers.formatter_spacing"] = { "string" },
	["buffers.sort_buffers"] = listof("function", false),
	["buffers.sort_directories"] = { "function" },
	["buffers.directories_first"] = { "boolean" },
	["buffers.bufname_align"] = oneof("none", "left", "right"),
	["buffers.bufname_style"] = oneof("basename", "unique", "hide"),
	["buffers.bufpath_style"] = oneof("full", "short", "relhome", "relcwd", "hide"),
	["buffers.directory_handler"] = { "function" },
	["buffers.tree_lines"] = listof("string", false, 4),

	["buffers.mappings"] = { "table" },
	["buffers.mappings.cycle_sort"] = listof("string"),
	["buffers.mappings.pin_increment"] = listof("string"),
	["buffers.mappings.pin_decrement"] = listof("string"),
	["buffers.mappings.toggle_pin"] = listof("string"),
	["buffers.mappings.add_directory"] = listof("string"),
	["buffers.mappings.toggle_unlisted"] = listof("string"),
	["buffers.mappings.edit"] = listof("string"),
	["buffers.mappings.close"] = listof("string"),
	["buffers.mappings.tab"] = listof("string"),
	["buffers.mappings.split"] = listof("string"),
	["buffers.mappings.vsplit"] = listof("string"),
	["buffers.mappings.delete"] = listof("string"),
	["buffers.mappings.force_delete"] = listof("string"),
	["buffers.mappings.wipe"] = listof("string"),
	["buffers.mappings.force_wipe"] = listof("string"),

	["buffers.formatters"] = { "table" },
	["buffers.formatters.buffer"] = { "function" },
	["buffers.formatters.tree_root"] = { "function" },
	["buffers.formatters.tree_buffer"] = { "function" },
	["buffers.formatters.tree_directory"] = { "function" },

	["buffers.highlights"] = { "table" },
	["buffers.highlights.bufname"] = { "string" },
	["buffers.highlights.bufpath"] = { "string" },
	["buffers.highlights.unlisted"] = { "string" },
	["buffers.highlights.directory"] = { "string" },
	["buffers.highlights.modified"] = { "string" },
	["buffers.highlights.pin_position"] = { "string" },
	["buffers.highlights.pin_separator"] = { "string" },
	["buffers.highlights.tree_root"] = { "string" },
	["buffers.highlights.tree_lines"] = { "string" },
}
