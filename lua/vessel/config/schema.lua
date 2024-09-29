---@module "schema"

--- Check if a list contains only values of the given type
---@param typ string
---@param len integer?
---@return function
local function listof(typ, len)
	return function(t)
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
		return true
	end
end

return {

	["verbosity"] = {"number"},
	["lazy_load_buffers"] = {"boolean"},
	["highlight_on_jump"] = {"boolean"},
	["highlight_timeout"] = {"number"},
	["jump_callback"] = {"function"},

	["window"] = {"table"},
	["window.max_height"] = {"number"},
	["window.cursorline"] = {"boolean"},
	["window.number"] = {"boolean"},
	["window.relativenumber"] = {"boolean"},
	["window.options"] = {"table"},
	["window.options.relative"] = {"string"},
	["window.options.anchor"] = {"string"},
	["window.options.style"] = {"string"},
	["window.options.border"] = {"string"},
	["window.options.width"] = {{"function", "number"}},
	["window.options.height"] = {{"function", "number"}},
	["window.options.row"] = {{"function", "number"}},
	["window.options.col"] = {{"function", "number"}},

	["create_commands"] = {"boolean"},
	["commands"] = {"table"},
	["commands.view_marks"] = {"string"},
	["commands.view_jumps"] = {"string"},

	["marks"] = {"table"},
	["marks.locals"] = {"string"},
	["marks.globals"] = {"string"},
	["marks.sort_marks"] = {"function"},
	["marks.sort_groups"] = {"function"},
	["marks.toggle_mark"] = {"boolean"},
	["marks.use_backtick"] = {"boolean"},
	["marks.not_found"] = {"string"},
	["marks.move_to_first_mark"] = {"boolean"},
	["marks.move_to_closest_mark"] = {"boolean"},
	["marks.proximity_threshold"] = {"number"},
	["marks.force_header"] = {"boolean"},
	["marks.decorations"] = {listof("string", 2), "list of 2 strings"},
	["marks.show_colnr"] = {"boolean"},
	["marks.strip_lines"] = {"boolean"},
	["marks.formatters"] = {"table"},
	["marks.formatters.mark"] = {"function"},
	["marks.formatters.header"] = {"function"},
	["marks.highlights"] = {"table"},
	["marks.highlights.path"] = {"string"},
	["marks.highlights.not_loaded"] = {"string"},
	["marks.highlights.decorations"] = {"string"},
	["marks.highlights.mark"] = {"string"},
	["marks.highlights.lnum"] = {"string"},
	["marks.highlights.col"] = {"string"},
	["marks.highlights.line"] = {"string"},
	["marks.mappings"] = {"table"},
	["marks.mappings.close"] = {listof("string"), "list of strings"},
	["marks.mappings.delete"] = {listof("string"), "list of strings"},
	["marks.mappings.next_group"] = {listof("string"), "list of strings"},
	["marks.mappings.prev_group"] = {listof("string"), "list of strings"},
	["marks.mappings.jump"] = {listof("string"), "list of strings"},
	["marks.mappings.keepj_jump"] = {listof("string"), "list of strings"},
	["marks.mappings.tab"] = {listof("string"), "list of strings"},
	["marks.mappings.keepj_tab"] = {listof("string"), "list of strings"},
	["marks.mappings.split"] = {listof("string"), "list of strings"},
	["marks.mappings.keepj_split"] = {listof("string"), "list of strings"},
	["marks.mappings.vsplit"] = {listof("string"), "list of strings"},
	["marks.mappings.keepj_vsplit"] = {listof("string"), "list of strings"},

	["jumps"] = {"table"},
	["jumps.rel_virtual"] = {"boolean"},
	["jumps.strip_lines"] = {"boolean"},
	["jumps.filter_empty_lines"] = {"boolean"},
	["jumps.not_found"] = {"string"},
	["jumps.indicator"] = {listof("string", 2), "list of 2 strings"},
	["jumps.show_colnr"] = {"boolean"},
	["jumps.mappings"] = {"table"},
	["jumps.mappings.ctrl_o"] = {"string"},
	["jumps.mappings.ctrl_i"] = {"string"},
	["jumps.mappings.jump"] = {listof("string"), "list of strings"},
	["jumps.mappings.close"] = {listof("string"), "list of strings"},
	["jumps.mappings.clear"] = {listof("string"), "list of strings"},
	["jumps.formatters"] = {"table"},
	["jumps.formatters.jump"] = {"function"},
	["jumps.highlights"] = {"table"},
	["jumps.highlights.indicator"] = {"string"},
	["jumps.highlights.pos"] = {"string"},
	["jumps.highlights.current_pos"] = {"string"},
	["jumps.highlights.path"] = {"string"},
	["jumps.highlights.lnum"] = {"string"},
	["jumps.highlights.col"] = {"string"},
	["jumps.highlights.line"] = {"string"},
}
