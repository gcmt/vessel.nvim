---@module "bufferlist"

local BufWriter = require("vessel.bufwriter")
local Context = require("vessel.context")
local FileStore = require("vessel.filestore")
local Window = require("vessel.window")
local help = require("vessel.help")
local logger = require("vessel.logger")
local tree = require("vessel.bufferlist.tree")
local util = require("vessel.util")

-- For stateful view preference
local VIEW
-- For stateful squash preference
local SQUASH
-- For stateful sorting
local SORT_FUNC
-- Custom tree roots
local TREE_GROUPS = {}
-- Collapsed directory nodes
local COLLAPSED = {}
-- List of pinned buffers (only numbers)
local PINNED = {}

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
---@field bufft string Buffer filetype
---@field config table Gloabl config
---@field context Context Info about the current buffer/window
---@field window Window The main popup window
---@field filestore FileStore File cache
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
	buffers.bufft = "bufferlist"
	buffers.config = config
	buffers.context = Context:new()
	buffers.window = Window:new(config, buffers.context)
	buffers.filestore = FileStore:new()
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
	local bufnr, ok = self.window:open(math.max(listed, 1), self.config.buffers.preview)
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
	return PINNED
end

--- Return the next pinned buffer number
---@param bufnr integer
---@return integer?
function Bufferlist:get_pinned_next(bufnr)
	for i, nr in ipairs(PINNED) do
		if nr == bufnr then
			local index = i + 1
			if index > #PINNED then
				if not self.config.buffers.wrap_around then
					return
				else
					index = 1
				end
			end
			return PINNED[index]
		end
	end
end

--- Return the previous pinned buffer number
---@param bufnr integer
---@return integer?
function Bufferlist:get_pinned_prev(bufnr)
	for i, nr in ipairs(PINNED) do
		if nr == bufnr then
			local index = i - 1
			if index < 1 then
				if not self.config.buffers.wrap_around then
					return
				else
					index = #PINNED
				end
			end
			return PINNED[index]
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

--- Toggle custom group
---@param map table
function Bufferlist:_action_toggle_group(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	local path
	if type(selected) == "string" then
		path = selected
	else
		path = vim.fs.dirname(selected.path)
	end

	local index
	for i, _path in ipairs(TREE_GROUPS) do
		if _path == path then
			index = i
		end
	end

	if index then
		table.remove(TREE_GROUPS, index)
	else
		table.insert(TREE_GROUPS, 1, path)
	end

	local newmap = self:_refresh()
	self:_follow_selected(selected, newmap)
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

	local path
	if type(selected) == "string" then
		path = selected
	else
		path = selected.path
	end

	if COLLAPSED[path] then
		-- open collapsed directory
		COLLAPSED[path] = nil
		self:_refresh()
		vim.cmd("norm! j")
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

--- Move to next/prev group
---@param map table
---@param backwards boolean
function Bufferlist:_action_next_group(map, backwards)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	local path
	if type(selected) == "string" then
		path = selected
	else
		path = selected.path
	end

	-- Find group under cursor. If a buffer is selected, check parent
	-- directories instead
	local current_pos
	while not current_pos and path ~= "/" do
		for i, group in ipairs(TREE_GROUPS) do
			if path == group then
				current_pos = i
				break
			end
		end
		path = vim.fs.dirname(path)
	end

	if not current_pos then
		return
	end

	local next_pos = current_pos + (backwards and -1 or 1)
	local next_group = TREE_GROUPS[next_pos]

	if not next_group then
		return
	end

	for i, entry in pairs(map) do
		if type(entry) == "string" and entry == next_group then
			util.cursor(i, 1)
			break
		end
	end
end

--- Move group position
---@param map table
---@param increment integer (1 or -1)
function Bufferlist:_action_move_group(map, increment)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	local path
	if type(selected) == "string" then
		path = selected
	else
		path = selected.path
	end

	-- Find group under cursor. If a buffer is selected, check parent
	-- directories instead
	local group_pos
	while not group_pos and path ~= "/" do
		for i, group in ipairs(TREE_GROUPS) do
			if path == group then
				group_pos = i
				break
			end
		end
		path = vim.fs.dirname(path)
	end

	if not group_pos then
		return
	end

	local new_pos = group_pos + increment
	if new_pos >= 1 and new_pos <= #TREE_GROUPS then
		table.insert(TREE_GROUPS, new_pos, table.remove(TREE_GROUPS, group_pos))
	end

	local newmap = self:_refresh()
	self:_follow_selected(selected, newmap)
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
		table.insert(PINNED, selected.nr)
	else
		local newpos = selected.pinpos + increment
		if newpos >= 1 and newpos <= #PINNED then
			table.remove(PINNED, selected.pinpos)
			table.insert(PINNED, selected.pinpos + increment, selected.nr)
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
	for i, nr in ipairs(PINNED) do
		if nr == bufnr then
			index = i
		end
	end

	if index then
		table.remove(PINNED, index)
	else
		table.insert(PINNED, bufnr)
	end

	local newmap = self:_refresh()
	if type(selected) == "string" then
		-- intermediate directory nodes don't disappear from the tree
		self:_follow_selected(selected, newmap)
	end
end

--- Collapse directory node in tree view
---@param map table
function Bufferlist:_action_collapse_directory(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	local path
	if type(selected) == "string" then
		path = selected
	else
		if selected.isdirectory then
			path = selected.path
		else
			path = vim.fs.dirname(selected.path)
		end
	end

	COLLAPSED[path] = true
	local newmap = self:_refresh()
	self:_follow_selected(path, newmap)
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

--- Toggle squash option
---@param map table
function Bufferlist:_action_toggle_squash(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end
	SQUASH = not SQUASH
	local newmap = self:_refresh()
	self:_follow_selected(selected, newmap)
end

--- Toggle view option
---@param map table
function Bufferlist:_action_toggle_view(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end
	if VIEW == "tree" then
		VIEW = "flat"
	else
		VIEW = "tree"
	end
	local newmap = self:_refresh()
	self:_follow_selected(selected, newmap)
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

	local bufpath = selected.path or selected
	local bufnr = selected.nr or vim.fn.bufnr(bufpath)
	local pinpos = selected.pinpos or -1

	if bufnr == -1 then
		return
	end

	-- windows containing the buffer we want to delete
	local windows = {}
	for _, win in pairs(vim.fn.getwininfo()) do
		if win.bufnr == bufnr then
			table.insert(windows, win.winid)
		end
	end

	local repl = util.find_repl_buf(bufnr)
	if not repl then
		if bufpath == "" then
			logger.info("can't delete last buffer")
			return
		end
		repl = vim.api.nvim_create_buf(true, false)
	end

	local modified = vim.fn.getbufvar(bufnr, "&modified", 0) == 1
	if not modified or force then
		for _, win in pairs(windows) do
			vim.api.nvim_win_set_buf(win, repl)
		end
	end

	-- calling :bdel or :bwipe in the context of the floating window has no
	-- effect when the buffer is displayed in a window
	local winid = vim.fn.getwininfo()[1].winid
	cmd = force and cmd .. "!" or cmd
	local ok, err = pcall(vim.fn.win_execute, winid, cmd .. " " .. bufnr)
	if not ok then
		logger.warn(string.gsub(err, ".-:E%d+:%s+", ""))
		return
	end

	table.remove(PINNED, pinpos)
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
		-- SORT_FUNC is module-local
		if SORT_FUNC == funcs[i] then
			index = i
			break
		end
	end
	SORT_FUNC = funcs[(index % #funcs) + 1]
	local _, description = SORT_FUNC()
	logger.info("vessel: %s", description)
	local newmap = self:_refresh()
	self:_follow_selected(selected, newmap)
end

--- Render help inside the window
---@param map table
function Bufferlist:_action_show_help(map)
	self.window.preview:clear()
	for k in pairs(map) do
		map[k] = nil
	end
	local function close_handler()
		self:_render()
	end
	help.render(
		self.bufnr,
		"Buffer list help",
		self.config.buffers.mappings,
		require("vessel.bufferlist.helptext"),
		close_handler
	)
	self.window:fit_content()
end

--- Setup mappings for the buffer list window
---@param map table
function Bufferlist:_setup_mappings(map)
	util.keymap("n", self.config.help_key, function()
		self:_action_show_help(map)
	end)
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
	util.keymap("n", self.config.buffers.mappings.toggle_view, function()
		self:_action_toggle_view(map)
	end)
	-- quick edit for the 9 buffers at the top of the list
	if self.config.buffers.quickjump then
		for i = 1, 9 do
			util.keymap("n", tostring(i), function()
				self:_action_edit(map, util.modes.BUFFER, i)
			end)
		end
	end
	-- tree view-only mappings
	if VIEW == "tree" then
		util.keymap("n", self.config.buffers.mappings.toggle_group, function()
			self:_action_toggle_group(map)
		end)
		util.keymap("n", self.config.buffers.mappings.collapse_directory, function()
			self:_action_collapse_directory(map)
		end)
		util.keymap("n", self.config.buffers.mappings.toggle_squash, function()
			self:_action_toggle_squash(map)
		end)
		util.keymap("n", self.config.buffers.mappings.move_group_up, function()
			self:_action_move_group(map, -1)
		end)
		util.keymap("n", self.config.buffers.mappings.move_group_down, function()
			self:_action_move_group(map, 1)
		end)
		util.keymap("n", self.config.buffers.mappings.prev_group, function()
			self:_action_next_group(map, true)
		end)
		util.keymap("n", self.config.buffers.mappings.next_group, function()
			self:_action_next_group(map, false)
		end)
	end
end

--- Retrieve the buffer list
---@return table
function Bufferlist:_get_buffers()
	local pinpos = {}
	for i, nr in pairs(PINNED) do
		pinpos[nr] = i
	end

	local buffers = {}
	for _, b in pairs(vim.fn.getbufinfo()) do
		if vim.fn.getbufvar(b.bufnr, "&buftype") ~= "" then
			if pinpos[b.bufnr] then
				table.remove(PINNED, pinpos[b.bufnr])
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
			self.filestore:store(buffer.path)
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
		pinned_count = #PINNED,
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
---@param data Buffer|string Buffer or path to format
---@param meta table Contextual info
function Bufferlist:_format(formatter, data, meta)
	local ok, line, matches = pcall(formatter, data, meta, self.context, self.config)
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

--- Sort buffers and directories
---@param list any[]
---@param dir_fn function Function for filtering directories
---@param sort_dirs_fn function Function for sorting directories
---@param sort_buf_fn function Function for sorting regular buffers
---@return any[]
function Bufferlist:_sort(list, dir_fn, sort_dirs_fn, sort_buf_fn)
	local directories, rest = {}, {}
	for _, item in ipairs(list) do
		if dir_fn(item) then
			table.insert(directories, item)
		else
			table.insert(rest, item)
		end
	end

	local ok, err = pcall(table.sort, directories, sort_dirs_fn)
	if not ok then
		local msg = string.gsub(tostring(err), "^.*:%s+", "")
		logger.err("directories sorting error: %s", msg)
	end

	ok, err = pcall(table.sort, rest, sort_buf_fn)
	if not ok then
		local msg = string.gsub(tostring(err), "^.*:%s+", "")
		logger.err("buffers sorting error: %s", msg)
	end

	local order
	if self.config.buffers.directories_first then
		order = { a = directories, b = rest }
	else
		order = { b = directories, a = rest }
	end

	local ret = {}
	for _, item in ipairs(order.a) do
		table.insert(ret, item)
	end
	for _, item in ipairs(order.b) do
		table.insert(ret, item)
	end

	return ret
end

--- Retrun current buffer sorting function
---@return function, string
function Bufferlist:_sort_buf_function()
	local sort_func = SORT_FUNC or self.config.buffers.sort_buffers[1]
	return sort_func()
end

--- Render buffer list as a tree
---@param bufwriter BufWriter
---@param map table
---@param buffers Buffer[] Buffer list
function Bufferlist:_render_tree(bufwriter, map, buffers)
	local root_formatter = self.config.buffers.formatters.tree_root
	local buf_formatter = self.config.buffers.formatters.tree_buffer
	local dir_formatter = self.config.buffers.formatters.tree_directory

	local dirs_fn = function(node)
		return not node.buffer or node.buffer.isdirectory
	end
	local sort_dirs_fn = function(a, b)
		return self.config.buffers.sort_directories(a.path, b.path)
	end
	local sort_fn = self:_sort_buf_function()
	local sort_buf_fn = function(a, b)
		return sort_fn(a.buffer, b.buffer)
	end

	local function _render_tree(tree, root_dir, padding, is_last)
		local curr_padding = ""
		local next_padding = padding
		local lines = self.config.buffers.tree_lines
		local full_path = vim.fs.joinpath(root_dir, tree.path)

		if not tree.parent then
			-- print root directory !! root_dir == tree.path !!
			local line, matches = self:_format(root_formatter, tree.path, { prefix = curr_padding })
			bufwriter:append(line, matches)
			map[bufwriter.lnum] = tree.path
		else
			curr_padding = padding .. (is_last and lines[3] or lines[2])
			next_padding = padding .. (is_last and lines[4] or lines[1])

			local meta = { prefix = curr_padding, root = root_dir }
			if not tree.buffer or tree.buffer.isdirectory then
				local parent_full_path
				if tree.parent.parent then
					parent_full_path = vim.fs.joinpath(root_dir, tree.parent.path)
				else
					parent_full_path = root_dir
				end

				meta.squashed = false
				if SQUASH == nil then
					SQUASH = self.config.buffers.squash_directories
				end
				if SQUASH then
					local next = tree:fast_forward()
					if next then
						tree = next
						meta.squashed = true
						full_path = vim.fs.joinpath(root_dir, tree.path)
					end
				end

				meta.collapsed = false
				if COLLAPSED[full_path] then
					meta.collapsed = true
					meta.hidden_buffers = tree:count_buffers()
				end

				-- NOTE: directory nodes, when buffers, can be childless
				meta.rel_path = tree.path
				if meta.squashed then
					meta.squashed_path = util.replstart(full_path, parent_full_path .. "/", "")
				end
				local line, matches = self:_format(dir_formatter, full_path, meta)
				bufwriter:append(line, matches)
				map[bufwriter.lnum] = full_path
			else
				local line, matches = self:_format(buf_formatter, tree.buffer, meta)
				bufwriter:append(line, matches)
				map[bufwriter.lnum] = tree.buffer
			end
		end

		if COLLAPSED[full_path] then
			return
		end

		local children = self:_sort(tree.children, dirs_fn, sort_dirs_fn, sort_buf_fn)

		for k, child in ipairs(children) do
			_render_tree(child, root_dir, next_padding, k == #tree.children)
		end
	end

	local _buffers = {}
	for _, buffer in pairs(buffers) do
		if self._show_unlisted or buffer.listed then
			table.insert(_buffers, buffer)
		end
	end

	local trees = tree.make_trees(_buffers, TREE_GROUPS)

	trees = vim.tbl_filter(function(t)
		return not t:is_leaf()
	end, trees)

	TREE_GROUPS = {}
	for _, t in ipairs(trees) do
		table.insert(TREE_GROUPS, t.path)
	end

	for i, t in ipairs(trees) do
		local ok, err = pcall(_render_tree, t, t.path, "", false)
		if not ok then
			logger.err(string.gsub(tostring(err), "^.-:%d+:%s+", ""))
			return
		end
		if i ~= #trees then
			self:_render_separator(
				bufwriter,
				self.config.buffers.group_separator,
				self.config.buffers.highlights.group_separator
			)
		end
	end
end

--- Render a flat buffer list
---@param bufwriter BufWriter
---@param map table
---@param buffers Buffer[] Buffer list
---@param meta table Contextual info to pass to formatters
function Bufferlist:_render_flat(bufwriter, map, buffers, meta)
	local formatter = self.config.buffers.formatters.buffer
	for _, buffer in pairs(buffers) do
		if self._show_unlisted or buffer.listed then
			meta.current_line = bufwriter.lnum
			local line, matches, err = self:_format(formatter, buffer, meta)
			if err then
				logger.err(err)
				return
			end
			bufwriter:append(line, matches)
			map[bufwriter.lnum] = buffer
		end
	end
end

--- Render a separator line between pinned and unpinned buffers
---@param bufwriter BufWriter
---@param sep integer Separator character
function Bufferlist:_render_separator(bufwriter, sep, hlgroup)
	if sep ~= "" then
		local separator = string.rep(sep, vim.fn.winwidth(0))
		local match = { hlgroup = hlgroup, startpos = 1, endpos = -1 }
		bufwriter:append(separator, { match })
	end
end

--- Render the buffer list in the given buffer
---@return table Table Maps each line to the buffer displayed on it
function Bufferlist:_render()
	local bufwriter = BufWriter:new(self.bufnr):init()
	local preview_aug = vim.api.nvim_create_augroup("VesselPreview", { clear = true })

	if #self.buffers == 0 then
		bufwriter:append(self.config.buffers.not_found):freeze()
		self.window:fit_content()
		self:_setup_mappings({})
		self.window:_set_buffer_data({})
		vim.cmd("doau User VesselBufferlistChanged")
		self.window.preview:clear()
		return {}
	end

	if VIEW == nil then
		VIEW = self.config.buffers.view
	end

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

	local meta
	if VIEW == "tree" then
		-- when in tree view mode, meta info makes sense only for pinned buffers
		meta = _get_meta(pinned)
	else
		meta = _get_meta(self.buffers)
	end

	local map = {}

	-- render pinned buffers first
	self:_render_flat(bufwriter, map, pinned, meta)

	-- render the separator only if there are unpinned visible buffers
	if bufwriter.lnum > 0 and unpinned_listed_count > 0 then
		self:_render_separator(
			bufwriter,
			self.config.buffers.pin_separator,
			self.config.buffers.highlights.pin_separator
		)
	end

	-- render unpinned buffers
	if VIEW == "tree" then
		self:_render_tree(bufwriter, map, unpinned)
	else
		local ok, err = pcall(table.sort, unpinned, self:_sort_buf_function())
		if not ok then
			local msg = string.gsub(tostring(err), "^.*:%s+", "")
			logger.err("sorting error: %s", msg)
			return {}
		end
		local dirs_fn = function(buffer)
			return buffer.isdirectory
		end
		local sort_dirs_fn = function(a, b)
			return self.config.buffers.sort_directories(a.path, b.path)
		end
		local sort_buf_fn = self:_sort_buf_function()
		unpinned = self:_sort(unpinned, dirs_fn, sort_dirs_fn, sort_buf_fn)
		self:_render_flat(bufwriter, map, unpinned, meta)
	end

	bufwriter:freeze()
	self:_setup_mappings(map)
	self.window:fit_content()
	self.window:_set_buffer_data(map)
	vim.cmd("doau User VesselBufferlistChanged")

	if self.window.preview.bufnr ~= -1 then
		-- Show the file under cursor content in the preview popup
		vim.api.nvim_create_autocmd("CursorMoved", {
			desc = "Write to the preview window on every movement",
			group = preview_aug,
			buffer = self.bufnr,
			callback = function()
				local selected = map[vim.fn.line(".")]
				local path, ft
				if type(selected) == "table" then
					path = selected.path
					ft = vim.fn.getbufvar(selected.nr, "&filetype")
				else
					path = selected
				end
				self.window.preview:show(self.filestore, path, 1, ft)
			end,
		})
	end

	return map
end

return Bufferlist
