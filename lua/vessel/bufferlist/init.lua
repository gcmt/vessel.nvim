---@module "bufferlist"

local Context = require("vessel.context")
local Window = require("vessel.window")
local logger = require("vessel.logger")
local tree = require("vessel.bufferlist.tree")
local util = require("vessel.util")

-- For stateful sorting
local Sort_func

-- List of pinned buffers (only numbers)
local Pinned = {}

---@class Buffer
---@field nr integer Buffer number
---@field path string Buffer full path
---@field isdirectory boolean Whether the buffer is a directory
---@field filetype string Buffer file type
---@field listed boolean Whether the buffer is listed
---@field modified boolean Whether the buffer is modified/changed
---@field changedtick integer Number total changes made to the buffer
---@field loaded boolean Whether the buffer is loaded
---@field hidden boolean Whether the buffer is hidden
---@field lastused integer When the buffer  was last used (unix timestamp)
---@field pinpos integer > 0 for pinned buffers
local Buffer = {}
Buffer.__index = Buffer

--- Create a new Buffer instance
---@param bufnr integer?
---@return Buffer
function Buffer:new(bufnr)
	local buffer = {}
	setmetatable(buffer, Buffer)
	buffer.nr = bufnr or -1
	buffer.path = ""
	buffer.listed = false
	buffer.modified = false
	buffer.changedtick = 0
	buffer.loaded = false
	buffer.isdirectory = false
	buffer.filetype = ""
	buffer.hidden = false
	buffer.lastused = 0
	buffer.pinpos = -1
	return buffer
end

---@class Bufferlist
---@field nsid integer Namespace id for highlighting
---@field bufft string Buffer filetype
---@field config table Gloabl config
---@field context Context Info about the current buffer/window
---@field window Window The main popup window
---@field bufnr integer Where jumps will be displayed
---@field buffers table Buffer list
---@field show_unlisted boolean Show/hide unlisted buffers
---@field filter_func function?
local Bufferlist = {}
Bufferlist.__index = Bufferlist

--- Return a new Bufferlist instance
---@param config table
---@param filter_func function?
---@return Bufferlist
function Bufferlist:new(config, filter_func)
	local buffers = {}
	setmetatable(buffers, Bufferlist)
	buffers.nsid = vim.api.nvim_create_namespace("__vessel__")
	buffers.bufft = "bufferlist"
	buffers.config = config
	buffers.context = Context:new()
	buffers.window = Window:new(config, buffers.context)
	buffers.bufnr = -1
	buffers.buffers = {}
	buffers.show_unlisted = false
	buffers.filter_func = filter_func
	return buffers
end

--- Initialize Bufferlist
---@return Bufferlist
function Bufferlist:init()
	self.buffers = self:_get_buffers()
	return self
end

--- Open the window and render the content
function Bufferlist:open()
	self:init()
	local listed = 0
	for _, buf in pairs(self.buffers) do
		if buf.listed then
			listed = listed + 1
		end
	end
	local bufnr, ok = self.window:open(math.max(listed, 1), false)
	if ok then
		self.bufnr = bufnr
		vim.fn.setbufvar(bufnr, "&filetype", self.bufft)
		vim.cmd("doau User VesselBufferlistEnter")
		self:_set_cursor(self:_render())
	end
end

--- Return pinned buffer list
---@return table
function Bufferlist:get_pinned_list()
	return Pinned
end

--- Return the next pinned buffer number
---@param bufnr integer
---@return integer?
function Bufferlist:get_pinned_next(bufnr)
	for i, nr in ipairs(Pinned) do
		if nr == bufnr then
			local index = i + 1
			if index > #Pinned then
				if not self.config.buffers.wrap_around then
					return
				else
					index = 1
				end
			end
			return Pinned[index]
		end
	end
end

--- Return the previous pinned buffer number
---@param bufnr integer
---@return integer?
function Bufferlist:get_pinned_prev(bufnr)
	for i, nr in ipairs(Pinned) do
		if nr == bufnr then
			local index = i - 1
			if index < 1 then
				if not self.config.buffers.wrap_around then
					return
				else
					index = #Pinned
				end
			end
			return Pinned[index]
		end
	end
end

--- Keep cursor on selected buffer
---@param selected Buffer|string Selected buffer or path
---@param map table New map table
function Bufferlist:_follow_selected(selected, map)
	local is_str = function(v)
		return type(v) == "string"
	end
	local is_tbl = function(v)
		return type(v) == "table"
	end
	for i, _ in pairs(map) do
		if
			is_tbl(map[i]) and is_tbl(selected) and map[i].nr == selected.nr
			or is_str(map[i]) and is_str(selected) and map[i] == selected
		then
			util.vcursor(i)
			break
		end
	end
end

--- Close the buffer list window
function Bufferlist:_action_close()
	self.window:_close_window()
end

--- Edit the buffer under cursor
---@param map table
---@param mode integer
---@param line integer?
function Bufferlist:_action_edit(map, mode, line)
	local target
	if line then
		target = line
	elseif vim.v.count > 0 then
		target = vim.v.count
	else
		target = vim.fn.line(".")
	end

	local selected = map[target]
	if not selected then
		return
	end

	self:_action_close()

	if mode == util.modes.SPLIT then
		vim.cmd("split")
	elseif mode == util.modes.VSPLIT then
		vim.cmd("vsplit")
	elseif mode == util.modes.TAB then
		vim.cmd("tab split")
	end

	if type(selected) == "string" and vim.fn.isdirectory(selected) == 1 then
		-- handle tree view directory nodes
		self.config.buffers.directory_handler(selected, self.context)
		return
	elseif vim.fn.isdirectory(selected.path) == 1 then
		self.config.buffers.directory_handler(selected.path, self.context)
		return
	elseif vim.fn.buflisted(selected.nr) == 1 then
		vim.cmd("buffer " .. selected.nr)
	else
		-- Unlike the 'buffer' command, the 'edit' command on unlisted buffers
		-- makes them listed again
		vim.cmd("edit " .. vim.fn.fnameescape(selected.path))
	end

	if self.config.jump_callback then
		self.config.jump_callback(mode, self.context)
	end

	if self.config.highlight_on_jump then
		util.cursorline(self.config.highlight_timeout)
	end
end

--- Increment/decrement pin position
--- If the buffer is not pinned, add it to pinned list
---@param map table
---@param increment integer (1 or -1)
function Bufferlist:_action_increment_pin_pos(map, increment)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end
	if selected.pinpos < 0 then
		table.insert(Pinned, selected.nr)
	else
		local newpos = selected.pinpos + increment
		if newpos >= 1 and newpos <= #Pinned then
			table.remove(Pinned, selected.pinpos)
			table.insert(Pinned, selected.pinpos + increment, selected.nr)
		end
	end
	local newmap = self:_refresh()
	self:_follow_selected(selected, newmap)
end

--- Pin/unpin the buffer under cursor
---@param map table
function Bufferlist:_action_toggle_pin(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	local bufnr
	if type(selected) == "string" then
		-- handle tree view directory nodes
		bufnr = vim.fn.bufnr(selected)
		if bufnr == -1 then
			bufnr = vim.fn.bufadd(selected)
			vim.fn.setbufvar(bufnr, "&buflisted", 1)
			logger.info('"%s" added to the buffer list', util.prettify_path(selected))
		end
	else
		bufnr = selected.nr
	end

	local index
	for i, nr in ipairs(Pinned) do
		if nr == bufnr then
			index = i
		end
	end

	if index then
		table.remove(Pinned, index)
	else
		table.insert(Pinned, bufnr)
	end

	local newmap = self:_refresh()
	if type(selected) == "string" then
		-- intermediate directory nodes don't disappear from the tree
		self:_follow_selected(selected, newmap)
	end
end

--- Add to the buffer list the directory of the buffer under cursor
---@param map table
---@return table
function Bufferlist:_action_add_directory(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return map
	end

	local path
	if type(selected) == "string" then
		-- handle tree view directory nodes
		path = selected
	else
		path = vim.fs.dirname(selected.path)
	end

	local bufnr = vim.fn.bufadd(path)
	vim.fn.setbufvar(bufnr, "&buflisted", 1)

	local newmap = self:_refresh()
	self:_follow_selected(Buffer:new(bufnr), newmap)
	logger.info('"%s" added to the buffer list', util.prettify_path(path))
	return newmap
end

--- Toggle unlisted buffes
---@param map table
function Bufferlist:_action_toggle_unlisted(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end
	local line = vim.fn.line(".")
	self._show_unlisted = not self._show_unlisted
	local newmap = self:_render()
	util.vcursor(line)
	self:_follow_selected(selected, newmap)
end

--- Delete/Wipe the buffer under cursor
---@param map table
---@param cmd string Delete command to use
---@param force boolean Ignore unsaved changes
function Bufferlist:_action_delete(map, cmd, force)
	local curline = vim.fn.line(".")
	local selected = map[curline]
	if not selected then
		return
	end

	if type(selected) == "string" then
		-- TODO: delete all buffers for the directory
		return
	end

	-- windows containing the buffer we want to delete
	local windows = {}
	for _, win in pairs(vim.fn.getwininfo()) do
		if win.bufnr == selected.nr then
			table.insert(windows, win.winid)
		end
	end

	-- Find replacement buffer
	local function _find_repl()
		for _, b in pairs(vim.fn.getbufinfo()) do
			if
				b.bufnr ~= selected.nr
				and b.listed == 1
				and vim.fn.getbufvar(b.bufnr, "&buftype") == ""
			then
				return b.bufnr
			end
		end
	end

	local repl = _find_repl()
	if not repl then
		if selected.path == "" then
			logger.info("can't delete last buffer")
			return
		end
		repl = vim.api.nvim_create_buf(true, false)
	end

	local modified = vim.fn.getbufvar(selected.nr, "&modified", 0) == 1
	if not modified or force then
		for _, win in pairs(windows) do
			vim.api.nvim_win_set_buf(win, repl)
		end
	end

	-- calling :bdel or :bwipe in the context of the floating window has no
	-- effect when the buffer is displayed in a window
	local winid = vim.fn.getwininfo()[1].winid
	cmd = force and cmd .. "!" or cmd
	local ok, err = pcall(vim.fn.win_execute, winid, cmd .. " " .. selected.nr)
	if not ok then
		logger.warn(string.gsub(err, ".-:E%d+:%s+", ""))
		return
	end

	table.remove(Pinned, selected.pinpos)
	self:_refresh()
end

--- Cycle sort functions
function Bufferlist:_action_cycle_sort(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end
	local funcs = self.config.buffers.sort_buffers
	local index = 1
	for i = 1, #funcs do
		-- Sort_func is module-local
		if Sort_func == funcs[i] then
			index = i
			break
		end
	end
	Sort_func = funcs[(index % #funcs) + 1]
	local _, description = Sort_func()
	logger.info("vessel: %s", description)
	local newmap = self:_refresh()
	self:_follow_selected(selected, newmap)
end

--- Setup mappings for the buffer list window
---@param map table
function Bufferlist:_setup_mappings(map)
	util.keymap("n", self.config.buffers.mappings.close, function()
		self:_action_close()
	end)
	util.keymap("n", self.config.buffers.mappings.cycle_sort, function()
		self:_action_cycle_sort(map)
	end)
	util.keymap("n", self.config.buffers.mappings.toggle_unlisted, function()
		self:_action_toggle_unlisted(map)
	end)
	util.keymap("n", self.config.buffers.mappings.pin_increment, function()
		self:_action_increment_pin_pos(map, 1)
	end)
	util.keymap("n", self.config.buffers.mappings.pin_decrement, function()
		self:_action_increment_pin_pos(map, -1)
	end)
	util.keymap("n", self.config.buffers.mappings.toggle_pin, function()
		self:_action_toggle_pin(map)
	end)
	util.keymap("n", self.config.buffers.mappings.add_directory, function()
		self:_action_add_directory(map)
	end)
	util.keymap("n", self.config.buffers.mappings.delete, function()
		self:_action_delete(map, "bdelete", false)
	end)
	util.keymap("n", self.config.buffers.mappings.force_delete, function()
		self:_action_delete(map, "bdelete", true)
	end)
	util.keymap("n", self.config.buffers.mappings.wipe, function()
		self:_action_delete(map, "bwipe", false)
	end)
	util.keymap("n", self.config.buffers.mappings.force_wipe, function()
		self:_action_delete(map, "bwipe", true)
	end)
	util.keymap("n", self.config.buffers.mappings.edit, function()
		self:_action_edit(map, util.modes.BUFFER)
	end)
	util.keymap("n", self.config.buffers.mappings.tab, function()
		self:_action_edit(map, util.modes.TAB)
	end)
	util.keymap("n", self.config.buffers.mappings.split, function()
		self:_action_edit(map, util.modes.SPLIT)
	end)
	util.keymap("n", self.config.buffers.mappings.vsplit, function()
		self:_action_edit(map, util.modes.VSPLIT)
	end)
	-- quick edit for the 9 buffers at the top of the list
	if self.config.buffers.quickjump then
		for i = 1, 9 do
			util.keymap("n", tostring(i), function()
				self:_action_edit(map, util.modes.BUFFER, i)
			end)
		end
	end
end

--- Retrieve the buffer list
---@return table
function Bufferlist:_get_buffers()
	local pinpos = {}
	for i, nr in pairs(Pinned) do
		pinpos[nr] = i
	end

	local buffers = {}
	for _, b in pairs(vim.fn.getbufinfo()) do
		if vim.fn.getbufvar(b.bufnr, "&buftype") ~= "" then
			if pinpos[b.bufnr] then
				table.remove(Pinned, pinpos[b.bufnr])
			end
			goto continue
		end

		local buffer = Buffer:new(b.bufnr)
		buffer.path = b.name
		buffer.listed = b.listed == 1
		buffer.modified = b.changed == 1
		buffer.changedtick = b.changedtick
		buffer.loaded = b.loaded == 1
		buffer.hidden = b.hidden == 1
		buffer.lastused = b.lastused
		buffer.isdirectory = vim.fn.isdirectory(b.name) == 1
		buffer.pinpos = pinpos[b.bufnr] or -1
		buffer.filetype = vim.api.nvim_get_option_value("filetype", { buf = b.bufnr })

		if self:_filter(buffer, self.context) then
			table.insert(buffers, buffer)
		end

		::continue::
	end

	return buffers
end

--- Filter a single buffer
---@param buffer Buffer
---@param context Context
---@return boolean
function Bufferlist:_filter(buffer, context)
	if self.filter_func and not self.filter_func(buffer, context) then
		return false
	end
	return true
end

--- Position the cursor on the current buffer
---Used just after the windows opens up
---@param map table
function Bufferlist:_set_cursor(map)
	vim.fn.cursor(1, 1)
	for line, buffer in pairs(map or {}) do
		if buffer.path == self.context.bufpath then
			vim.fn.cursor(line, 1)
			break
		end
	end
end

--- Re-render the buffer with new buffers
---@return table
function Bufferlist:_refresh()
	local line = vim.fn.line(".")
	self:init()
	local map = self:_render()
	util.vcursor(line, 1)
	return map
end

--- Get metadata table
---@param buffers Buffer[]
---@return table
local function _get_meta(buffers)
	local meta = {
		max_basename = 0,
		pinned_count = #Pinned,
		-- Maps each path to its shortest unique suffix
		suffixes = {},
		max_suffix = 0,
	}

	local paths = {}
	for _, buffer in pairs(buffers) do
		table.insert(paths, buffer.path)
		local basename_len = #vim.fs.basename(buffer.path)
		if not meta.max_basename or basename_len > meta.max_basename then
			meta.max_basename = basename_len
		end
	end

	meta.suffixes = util.unique_suffixes(paths)
	for _, suffix in pairs(meta.suffixes) do
		local suffix_len = vim.fn.strchars(suffix)
		if not meta.max_suffix or suffix_len > meta.max_suffix then
			meta.max_suffix = suffix_len
		end
	end

	return meta
end

--- Format Buffer with the given formatter
---@param formatter function Formatter function
---@param buffer Buffer Buffer to format
---@param meta table Contextual info
function Bufferlist:_format(formatter, buffer, meta)
	local ok, line, matches = pcall(formatter, buffer, meta, self.context, self.config)
	if not ok or not line then
		local msg
		if not line then
			msg = string.format("string expected, got nil")
		else
			msg = string.gsub(tostring(line), "^.*:%s+", "")
		end
		error(string.format("formatter error: %s", msg))
	end
	return line, matches
end

--- Set buffer line and setup highlighting
---@param map table
---@param lnum integer
---@param line string
---@param matches table
---@param data any
function Bufferlist:_set_buf_line(map, lnum, line, matches, data)
	map[lnum] = data
	vim.fn.setbufline(self.bufnr, lnum, line)
	util.set_matches(matches or {}, lnum, self.bufnr, self.nsid)
end

--- Render buffer list as a tree
---@param map table
---@param start integer Line after which start rendering
---@param buffers Buffer[] Buffer list
---@return integer Last rendered line
function Bufferlist:_render_tree(map, start, buffers)
	local root_formatter = self.config.buffers.formatters.tree_root
	local buf_formatter = self.config.buffers.formatters.tree_buffer
	local dir_formatter = self.config.buffers.formatters.tree_directory

	local i = start
	local function _render_tree(tree, prefix, padding, is_last)
		i = i + 1
		local curr_padding = ""
		local next_padding = padding
		local lines = self.config.buffers.tree_lines

		if not tree.parent then
			-- print root directory
			local line, matches = self:_format(root_formatter, tree.path, { prefix = curr_padding })
			self:_set_buf_line(map, i, line, matches, tree.path)
		else
			curr_padding = padding .. (is_last and lines[3] or lines[2])
			next_padding = padding .. (is_last and lines[4] or lines[1])
			local meta = { prefix = curr_padding }
			if not tree.buffer or tree.buffer and vim.fn.isdirectory(tree.buffer.path) == 1 then
				-- NOTE: directory nodes, when buffers, can be childless
				local line, matches = self:_format(dir_formatter, tree.path, meta)
				self:_set_buf_line(map, i, line, matches, vim.fs.joinpath(prefix, tree.path))
			else
				local line, matches = self:_format(buf_formatter, tree.buffer, meta)
				self:_set_buf_line(map, i, line, matches, tree.buffer)
			end
		end

		for k, child in ipairs(tree.children) do
			_render_tree(child, prefix, next_padding, k == #tree.children)
		end
	end

	local _buffers = {}
	for _, buffer in pairs(buffers) do
		if self._show_unlisted or buffer.listed then
			table.insert(_buffers, buffer)
		end
	end

	for _, t in ipairs(tree.make_trees(_buffers)) do
		if not t:is_leaf() then
			local ok, err = pcall(_render_tree, t, t.path, "", false)
			if not ok then
				logger.err(string.gsub(tostring(err), "^.-:%d+:%s+", ""))
				return i
			end
		end
	end

	return i
end

--- Render a flat buffer list
---@param map table
---@param start integer Line after which start rendering
---@param buffers Buffer[] Buffer list
---@param meta table Contextual info to pass to formatters
---@return integer Last rendered line
function Bufferlist:_render_flat(map, start, buffers, meta)
	local formatter = self.config.buffers.formatters.buffer
	local i = start
	for _, buffer in pairs(buffers) do
		if self._show_unlisted or buffer.listed then
			i = i + 1
			meta.current_line = i
			local line, matches, err = self:_format(formatter, buffer, meta)
			if err then
				logger.err(err)
				return i
			end
			self:_set_buf_line(map, i, line, matches, buffer)
		end
	end
	return i
end

--- Render a separator line between pinned and unpinned buffers
---@param start integer Line after which start rendering
---@return integer Last rendered line
function Bufferlist:_render_separator(start)
	local separator = self.config.buffers.pin_separator
	if separator == "" then
		return start
	end
	local i = start + 1
	vim.fn.setbufline(self.bufnr, i, string.rep(separator, vim.fn.winwidth(0)))
	local match = {
		hlgroup = self.config.buffers.highlights.pin_separator,
		startpos = 1,
		endpos = -1,
	}
	util.set_matches({ match }, i, self.bufnr, self.nsid)
	return i
end

--- Render the buffer list in the given buffer
---@return table Table Maps each line to the buffer displayed on it
function Bufferlist:_render()
	vim.fn.setbufvar(self.bufnr, "&modifiable", 1)
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
	vim.api.nvim_buf_clear_namespace(self.bufnr, self.nsid, 1, -1)

	if #self.buffers == 0 then
		vim.fn.setbufline(self.bufnr, 1, self.config.buffers.not_found)
		vim.fn.setbufvar(self.bufnr, "&modifiable", 0)
		self:_setup_mappings({})
		self.window:fit_content()
		self.window:_set_buffer_data({})
		vim.cmd("doau User VesselBufferlistChanged")
		return {}
	end

	local view = self.config.buffers.view

	local pinned = vim.tbl_filter(function(buffer)
		return buffer.pinpos > 0
	end, self.buffers)

	table.sort(pinned, function(a, b)
		return a.pinpos < b.pinpos
	end)

	local unpinned = {}
	local unpinned_listed_count = 0
	for _, buffer in pairs(self.buffers) do
		if buffer.pinpos < 0 then
			if buffer.listed then
				unpinned_listed_count = unpinned_listed_count + 1
			end
			table.insert(unpinned, buffer)
		end
	end

	if view == "flat" then
		local sort_func = Sort_func or self.config.buffers.sort_buffers[1]
		local func, _ = sort_func()
		local ok, err = pcall(table.sort, unpinned, func)
		if not ok then
			local msg = string.gsub(tostring(err), "^.*:%s+", "")
			logger.err("buffer sorting error: %s", msg)
			return {}
		end
	end

	local meta
	if view == "tree" then
		-- when in tree view mode, meta info makes sense only for pinned buffers
		meta = _get_meta(pinned)
	else
		meta = _get_meta(self.buffers)
	end

	local map = {}

	-- render pinned buffers first
	local i = self:_render_flat(map, 0, pinned, meta)

	-- render the separator only if there are unpinned visible buffers
	if i > 0 and unpinned_listed_count > 0 then
		i = self:_render_separator(i)
	end

	-- render unpinned buffers
	if view == "tree" then
		self:_render_tree(map, i, unpinned)
	else
		self:_render_flat(map, i, unpinned, meta)
	end

	vim.fn.setbufvar(self.bufnr, "&modifiable", 0)
	self:_setup_mappings(map)
	self.window:fit_content()
	self.window:_set_buffer_data(map)
	vim.cmd("doau User VesselBufferlistChanged")

	return map
end

return Bufferlist
