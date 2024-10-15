---@module "schema"

local logger = require("vessel.logger")

--- Allow list of the given type
---@param typ string
---@param allow_empty boolean? Allow empty string
---@param len integer? Allow list of specific length
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

-- Allow any of the given types
-- ... string
-- return table
local function typeof(...)
	return { ... }
end

--- Allow any of the given values
---@param ... any
---@return table
local function oneof(...)
	local t = { ... }
	local fn = function(val)
		for _, v in pairs(t) do
			if v == val then
				return true
			end
		end
		return false
	end
	return { fn, "one of " .. table.concat(t, "|") }
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

	__typeof = typeof,
	__listof = listof,
	__oneof = oneof,

	["verbosity"] = oneof(0, 1, 2, 3, 4, 5),
	["lazy_load_buffers"] = deprecated("lazy_load_buffers"),
	["highlight_on_jump"] = typeof("boolean"),
	["highlight_timeout"] = typeof("number"),
	["jump_callback"] = typeof("function"),
	["help_key"] = typeof("string"),

	["window"] = typeof("table"),
	["window.width"] = typeof("table", "function"), -- function or list of 2 numbers
	["window.gravity"] = oneof("center", "top"),
	["window.max_height"] = typeof("number"),
	["window.cursorline"] = typeof("boolean"),
	["window.number"] = typeof("boolean"),
	["window.relativenumber"] = typeof("boolean"),

	["window.options"] = typeof("table"),
	["window.options.style"] = typeof("string"),
	["window.options.border"] = typeof("string"),

	["preview"] = typeof("table"),
	["preview.position"] = oneof("right", "bottom"),
	["preview.width"] = typeof("number"),
	["preview.width_threshold"] = typeof("number"),
	["preview.min_height"] = typeof("number"),
	["preview.debounce"] = typeof("number"),

	["preview.options"] = typeof("table"),
	["preview.options.style"] = typeof("string"),
	["preview.options.border"] = typeof("string"),

	["create_commands"] = typeof("boolean"),

	["commands"] = typeof("table"),
	["commands.view_marks"] = typeof("string"),
	["commands.view_jumps"] = typeof("string"),
	["commands.view_buffers"] = typeof("string"),

	["marks"] = typeof("table"),
	["marks.preview"] = typeof("boolean"),
	["marks.locals"] = typeof("string"),
	["marks.globals"] = typeof("string"),
	["marks.sort_marks"] = listof("function", false),
	["marks.sort_groups"] = typeof("function"),
	["marks.toggle_mark"] = typeof("boolean"),
	["marks.use_backtick"] = typeof("boolean"),
	["marks.not_found"] = typeof("string"),
	["marks.move_to_first_mark"] = typeof("boolean"),
	["marks.move_to_closest_mark"] = typeof("boolean"),
	["marks.proximity_threshold"] = typeof("number"),
	["marks.force_header"] = typeof("boolean"),
	["marks.decorations"] = listof("string", false, 2),
	["marks.show_colnr"] = typeof("boolean"),
	["marks.strip_lines"] = typeof("boolean"),
	["marks.path_style"] = oneof("full", "short", "relhome", "relcwd"),

	["marks.formatters"] = typeof("table"),
	["marks.formatters.mark"] = typeof("function"),
	["marks.formatters.header"] = typeof("function"),

	["marks.highlights"] = typeof("table"),
	["marks.highlights.path"] = typeof("string"),
	["marks.highlights.not_loaded"] = typeof("string"),
	["marks.highlights.decorations"] = typeof("string"),
	["marks.highlights.mark"] = typeof("string"),
	["marks.highlights.lnum"] = typeof("string"),
	["marks.highlights.col"] = typeof("string"),
	["marks.highlights.line"] = typeof("string"),

	["marks.mappings"] = typeof("table"),
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
	["marks.mappings.cycle_sort"] = listof("string"),

	["jumps"] = typeof("table"),
	["jumps.preview"] = typeof("boolean"),
	["jumps.real_positions"] = typeof("boolean"),
	["jumps.strip_lines"] = typeof("boolean"),
	["jumps.filter_empty_lines"] = typeof("boolean"),
	["jumps.not_found"] = typeof("string"),
	["jumps.not_loaded"] = deprecated("jumps.not_loaded"),
	["jumps.indicator"] = listof("string", false, 2),
	["jumps.show_colnr"] = typeof("boolean"),
	["jumps.autoload_filter"] = deprecated("jumps.autoload_filter"),

	["jumps.mappings"] = typeof("table"),
	["jumps.mappings.ctrl_o"] = typeof("string"),
	["jumps.mappings.ctrl_i"] = typeof("string"),
	["jumps.mappings.jump"] = listof("string"),
	["jumps.mappings.close"] = listof("string"),
	["jumps.mappings.clear"] = listof("string"),
	["jumps.mappings.load_buffer"] = deprecated("jumps.mappings.load_buffer"),
	["jumps.mappings.load_all"] = deprecated("jumps.mappings.load_all"),
	["jumps.mappings.load_cwd"] = deprecated("jumps.mappings.load_cwd"),

	["jumps.formatters"] = typeof("table"),
	["jumps.formatters.jump"] = typeof("function"),

	["jumps.highlights"] = typeof("table"),
	["jumps.highlights.indicator"] = typeof("string"),
	["jumps.highlights.pos"] = typeof("string"),
	["jumps.highlights.current_pos"] = typeof("string"),
	["jumps.highlights.path"] = typeof("string"),
	["jumps.highlights.lnum"] = typeof("string"),
	["jumps.highlights.col"] = typeof("string"),
	["jumps.highlights.line"] = typeof("string"),
	["jumps.highlights.not_loaded"] = typeof("string"),

	["buffers"] = typeof("table"),
	["buffers.preview"] = typeof("boolean"),
	["buffers.view"] = oneof("flat", "tree"),
	["buffers.wrap_around"] = typeof("boolean"),
	["buffers.not_found"] = typeof("string"),
	["buffers.unnamed_label"] = typeof("string"),
	["buffers.quickjump"] = typeof("boolean"),
	["buffers.show_pin_positions"] = typeof("boolean"),
	["buffers.pin_separator"] = typeof("string"),
	["buffers.group_separator"] = typeof("string"),
	["buffers.formatter_spacing"] = typeof("string"),
	["buffers.sort_buffers"] = listof("function", false),
	["buffers.sort_directories"] = typeof("function"),
	["buffers.directories_first"] = typeof("boolean"),
	["buffers.squash_directories"] = typeof("boolean"),
	["buffers.bufname_align"] = oneof("none", "left", "right"),
	["buffers.bufname_style"] = oneof("basename", "unique", "hide"),
	["buffers.bufpath_style"] = oneof("full", "short", "relhome", "relcwd", "hide"),
	["buffers.directory_handler"] = typeof("function"),
	["buffers.tree_lines"] = listof("string", false, 4),
	["buffers.tree_folder_icons"] = listof("string", false, 2),

	["buffers.mappings"] = typeof("table"),
	["buffers.mappings.cycle_sort"] = listof("string"),
	["buffers.mappings.move_group_up"] = listof("string"),
	["buffers.mappings.move_group_down"] = listof("string"),
	["buffers.mappings.prev_group"] = listof("string"),
	["buffers.mappings.next_group"] = listof("string"),
	["buffers.mappings.pin_increment"] = listof("string"),
	["buffers.mappings.pin_decrement"] = listof("string"),
	["buffers.mappings.toggle_view"] = listof("string"),
	["buffers.mappings.toggle_group"] = listof("string"),
	["buffers.mappings.toggle_pin"] = listof("string"),
	["buffers.mappings.add_directory"] = listof("string"),
	["buffers.mappings.collapse_directory"] = listof("string"),
	["buffers.mappings.toggle_unlisted"] = listof("string"),
	["buffers.mappings.toggle_squash"] = listof("string"),
	["buffers.mappings.edit"] = listof("string"),
	["buffers.mappings.close"] = listof("string"),
	["buffers.mappings.tab"] = listof("string"),
	["buffers.mappings.split"] = listof("string"),
	["buffers.mappings.vsplit"] = listof("string"),
	["buffers.mappings.delete"] = listof("string"),
	["buffers.mappings.force_delete"] = listof("string"),
	["buffers.mappings.wipe"] = listof("string"),
	["buffers.mappings.force_wipe"] = listof("string"),

	["buffers.formatters"] = typeof("table"),
	["buffers.formatters.buffer"] = typeof("function"),
	["buffers.formatters.tree_root"] = typeof("function"),
	["buffers.formatters.tree_buffer"] = typeof("function"),
	["buffers.formatters.tree_directory"] = typeof("function"),

	["buffers.highlights"] = typeof("table"),
	["buffers.highlights.bufname"] = typeof("string"),
	["buffers.highlights.bufpath"] = typeof("string"),
	["buffers.highlights.unlisted"] = typeof("string"),
	["buffers.highlights.directory"] = typeof("string"),
	["buffers.highlights.modified"] = typeof("string"),
	["buffers.highlights.pin_position"] = typeof("string"),
	["buffers.highlights.pin_separator"] = typeof("string"),
	["buffers.highlights.group_separator"] = typeof("string"),
	["buffers.highlights.tree_root"] = typeof("string"),
	["buffers.highlights.tree_lines"] = typeof("string"),
	["buffers.highlights.hidden_count"] = typeof("string"),
}
