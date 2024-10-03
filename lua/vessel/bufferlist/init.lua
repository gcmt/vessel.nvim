---@module "bufferlist"

local logger = require("vessel.logger")
local util = require("vessel.util")

-- Stateful sort type
local Sort_func

---@class Buffer
---@field nr integer Buffer number
---@field path string Buffer full path
---@field listed boolean Buffer is listed
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
	return buffer
end

---@class Bufferlist
---@field _nsid integer Namespace id for highlighting
---@field _app App Reference to the main app
---@field _bufnr integer Buffer number where buffers will be displayed
---@field _bufft string Buffer filetype
---@field _buffers table Buffer list (unfiltered)
---@field _show_unlisted boolean Show/hide unlisted buffers
---@field _filter_func function?
local Bufferlist = {}
Bufferlist.__index = Bufferlist

--- Return a new Bufferlist instance
---@param app App
---@param filter_func function?
---@return Bufferlist
function Bufferlist:new(app, filter_func)
	local buffers = {}
	setmetatable(buffers, Bufferlist)
	buffers._nsid = vim.api.nvim_create_namespace("__vessel__")
	buffers._app = app
	buffers._bufft = "bufferlist"
	buffers._bufnr = -1
	buffers._buffers = {}
	buffers._show_unlisted = false
	buffers._filter_func = filter_func
	return buffers
end

--- Initialize Bufferlist
---@return Bufferlist
function Bufferlist:init()
	self._buffers = self:_get_buffers()
	return self
end

--- Open the window and render the content
function Bufferlist:open()
	self:init()
	local ok
	self._bufnr, ok = self._app:open_window(self)
	if ok then
		vim.fn.setbufvar(self._bufnr, "&filetype", self._bufft)
		vim.cmd("doau User VesselBufferlistEnter")
		self:_set_cursor(self:_render())
	end
end

--- Return total buffers count
---@return integer, integer
function Bufferlist:get_count()
	return #self._buffers, 1
end

--- Keep cursor on selected buffer
---@param selected Buffer Selected buffer
---@param map table New map table
function Bufferlist:_follow_selected(selected, map)
	for i, buffer in pairs(map) do
		if buffer.nr == selected.nr then
			util.vcursor(i)
			break
		end
	end
end

--- Close the buffer list window
function Bufferlist:_action_close()
	self._app:_close_window()
end

--- Edit the buffer under cursor
---@param map table
---@param mode integer
---@param line integer?
function Bufferlist:_action_edit(map, mode, line)
	local selected = map[line and line or vim.fn.line(".")]
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

	if vim.fn.isdirectory(selected.path) == 1 then
		self._app.config.buffers.directory_handler(selected.path, self._app.context)
		return
	elseif vim.fn.buflisted(selected.nr) == 1 then
		vim.cmd("buffer " .. selected.nr)
	else
		-- Unlike the 'buffer' command, the 'edit' command on unlisted buffers
		-- makes them listed again
		vim.cmd("edit " .. vim.fn.fnameescape(selected.path))
	end

	if self._app.config.jump_callback then
		self._app.config.jump_callback(mode, self._app.context)
	end

	if self._app.config.highlight_on_jump then
		util.cursorline(self._app.config.highlight_timeout)
	end
end

--- Toggle unlisted buffers
---@param map table
function Bufferlist:_action_toggle_unlisted(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end
	self._show_unlisted = not self._show_unlisted
	local newmap = self:_render()
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

	-- windows containing the buffer we want to delete
	local windows = {}
	for _, win in pairs(vim.fn.getwininfo()) do
		if win.bufnr == selected.nr then
			table.insert(windows, win.winid)
		end
	end

	-- Replacement buffer in case the target is being shown in a window
	local repl = map[(curline % vim.fn.line("$")) + 1]
	if repl.nr == selected.nr then
		if selected.path == "" then
			logger.info("Can't delete last unnamed buffer")
			return
		end
		repl = Buffer:new(vim.api.nvim_create_buf(true, false))
	end

	local modified = vim.fn.getbufvar(selected.nr, "&modified", 0) == 1
	if not modified or force then
		for _, win in pairs(windows) do
			vim.api.nvim_win_set_buf(win, repl.nr)
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

	self:_refresh()
end

--- Cycle sort functions
function Bufferlist:_action_cycle_sort(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end
	local funcs = self._app.config.buffers.sort_buffers
	local index = 1
	for i = 1, #funcs do
		-- Sort_func is module-local
		if Sort_func == funcs[i] then
			index = i
			break
		end
	end
	Sort_func = funcs[(index % #funcs) + 1]
	local newmap = self:_refresh()
	self:_follow_selected(selected, newmap)
end

--- Setup mappings for the buffer list window
---@param map table
function Bufferlist:_setup_mappings(map)
	util.keymap("n", self._app.config.buffers.mappings.close, function()
		self:_action_close()
	end)
	util.keymap("n", self._app.config.buffers.mappings.cycle_sort, function()
		self:_action_cycle_sort(map)
	end)
	util.keymap("n", self._app.config.buffers.mappings.toggle_unlisted, function()
		self:_action_toggle_unlisted(map)
	end)
	util.keymap("n", self._app.config.buffers.mappings.delete, function()
		self:_action_delete(map, "bdelete", false)
	end)
	util.keymap("n", self._app.config.buffers.mappings.force_delete, function()
		self:_action_delete(map, "bdelete", true)
	end)
	util.keymap("n", self._app.config.buffers.mappings.wipe, function()
		self:_action_delete(map, "bwipe", false)
	end)
	util.keymap("n", self._app.config.buffers.mappings.force_wipe, function()
		self:_action_delete(map, "bwipe", true)
	end)
	util.keymap("n", self._app.config.buffers.mappings.edit, function()
		self:_action_edit(map, util.modes.BUFFER)
	end)
	util.keymap("n", self._app.config.buffers.mappings.tab, function()
		self:_action_edit(map, util.modes.TAB)
	end)
	util.keymap("n", self._app.config.buffers.mappings.split, function()
		self:_action_edit(map, util.modes.SPLIT)
	end)
	util.keymap("n", self._app.config.buffers.mappings.vsplit, function()
		self:_action_edit(map, util.modes.VSPLIT)
	end)
	-- quick edit for the 9 buffers at the top of the list
	if self._app.config.buffers.quickjump then
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
	local buffers = {}
	for bufnr = 1, vim.fn.bufnr("$") do
		if vim.fn.bufexists(bufnr) == 0 or vim.fn.getbufvar(bufnr, "&buftype") ~= "" then
			goto continue
		end

		local buffer = Buffer:new(bufnr)
		buffer.path = vim.api.nvim_buf_get_name(bufnr)
		buffer.listed = vim.fn.buflisted(bufnr) == 1

		if self:_filter(buffer, self._app.context) then
			table.insert(buffers, buffer)
		end

		::continue::
	end

	local sort_func = Sort_func or self._app.config.buffers.sort_buffers[1]
	local func, description = sort_func()
	local ok, err = pcall(table.sort, buffers, func)
	if not ok then
		local msg = string.gsub(tostring(err), "^.*:%s+", "")
		logger.err("buffer sorting error: %s", msg)
		return {}
	elseif Sort_func and description ~= "" then
		-- give feedback only if Sort_func gets changed
		logger.info("vessel: %s", description)
	end

	return buffers
end

--- Filter a single buffer
---@param buffer Buffer
---@param context Context
---@return boolean
function Bufferlist:_filter(buffer, context)
	if self._filter_func and not self._filter_func(buffer, context) then
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
		if buffer.path == self._app.context.bufpath then
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

--- Render the buffer list in the given buffer
---@return table Table Maps each line to the buffer displayed on it
function Bufferlist:_render()
	vim.fn.setbufvar(self._bufnr, "&modifiable", 1)
	vim.cmd('sil! keepj norm! gg"_dG')
	vim.api.nvim_buf_clear_namespace(self._bufnr, self._nsid, 1, -1)

	if #self._buffers == 0 then
		vim.fn.setbufline(self._bufnr, 1, self._app.config.buffers.not_found)
		vim.fn.setbufvar(self._bufnr, "&modifiable", 0)
		self:_setup_mappings({})
		util.fit_content(self._app.config.window.max_height)
		self._app:_set_buffer_data({})
		vim.cmd("doau User VesselBufferlistChanged")
		return {}
	end

	local map = {}
	local max_suffix
	local max_basename
	local buf_formatter = self._app.config.buffers.formatters.buffer

	local paths = {}
	for _, buffer in pairs(self._buffers) do
		table.insert(paths, buffer.path)
		local basename_len = #vim.fs.basename(buffer.path)
		if not max_basename or basename_len > max_basename then
			max_basename = basename_len
		end
	end

	-- find for each path the shortest unique suffix
	local suffixes = util.unique_suffixes(paths)
	for _, suffix in pairs(suffixes) do
		local suffix_len = vim.fn.strchars(suffix)
		if not max_suffix or suffix_len > max_suffix then
			max_suffix = suffix_len
		end
	end

	local i = 0
	for _, buffer in pairs(self._buffers) do
		if not self._show_unlisted and not buffer.listed then
			goto continue
		end
		i = i + 1
		local ok, line, matches = pcall(buf_formatter, buffer, {
			current_line = i,
			max_basename = max_basename,
			max_suffix = max_suffix,
			suffixes = suffixes,
		}, self._app.context, self._app.config)
		if not ok or not line then
			local msg
			if not line then
				msg = string.format("line %s: string expected, got nil", i)
			else
				msg = string.gsub(tostring(line), "^.*:%s+", "")
			end
			self._app:_close_window()
			logger.err("formatter error: %s", msg)
			return {}
		end
		map[i] = buffer
		vim.fn.setbufline(self._bufnr, i, line)
		if matches then
			util.set_matches(matches, i, self._bufnr, self._nsid)
		end
		::continue::
	end

	vim.fn.setbufvar(self._bufnr, "&modifiable", 0)
	self:_setup_mappings(map)
	util.fit_content(self._app.config.window.max_height)
	self._app:_set_buffer_data(map)
	vim.cmd("doau User VesselBufferlistChanged")

	return map
end

return Bufferlist
