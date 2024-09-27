---@module "marklist"

local util = require("vessel.util")

---@class Mark
---@field mark string Mark letter
---@field lnum integer Mark line number
---@field col integer Mark column number
---@field line string Line on which the mark is positioned
---@field file string File the mark belongs to
---@field loaded boolean Whether the file is actually loaded in memory
local Mark = {}
Mark.__index = Mark

--- Return a new Mark instance
---@return Mark
function Mark:new()
	local mark = {}
	setmetatable(mark, Mark)
	mark.mark = ""
	mark.lnum = 0
	mark.col = 0
	mark.line = ""
	mark.file = ""
	mark.loaded = false
	return mark
end

---@class Marklist
---@field _nsid integer
---@field _app App
---@field _marks table Marks grouped by file
---@field _bufnr integer
---@field _filter_func function?
local Marklist = {}
Marklist.__index = Marklist

--- Return a new Marklist instance
---@param app App
---@param filter_func function?
---@return Marklist
function Marklist:new(app, filter_func)
	local marks = {}
	setmetatable(marks, Marklist)
	marks._nsid = vim.api.nvim_create_namespace("__vessel__")
	marks._app = app
	marks._marks = {}
	marks._bufnr = -1
	marks._filter_func = filter_func
	return marks
end

--- Initialize Markslist
---@return Marklist
function Marklist:init()
	self._marks = self:_get_marks(self._app.context.bufnr)
	return self
end

--- Open the window and render the content
function Marklist:open()
	self:init()
	local ok
	self._bufnr, ok = self._app:open_window(self)
	if ok then
		self:_render()
	end
end

--- Return total marks and groups count
---@return integer, integer
function Marklist:get_count()
	local marks_count, groups_count = 0, 0
	for _, group in pairs(self._marks) do
		groups_count = groups_count + 1
		marks_count = marks_count + #group
	end
	return marks_count, groups_count
end

--- Set a mark on the current line by choosing a letter automatically.
--- If the mark is already set, then it is deleted, Unless the 'toggle_mark'
--- option is set to false.
---@param global boolean Whether or not the mark should be global
---@return boolean
function Marklist:set_mark(global)
	local lnum = self._app.context.curpos[2]
	local bufpath = self._app.context.bufpath

	local marks = {}
	for _, group in pairs(self._marks) do
		for _, m in pairs(group) do
			marks[m.mark] = m
		end
	end

	-- Check if the mark is already set on the current line and if so, delete it
	for _, mark in pairs(marks) do
		if mark.file == bufpath and mark.lnum == lnum then
			if not self._app.config.marks.toggle_mark then
				self._app.logger:info('line "%s" already marked with [%s]', lnum, mark.mark)
				return false
			end
			vim.cmd.delmarks(mark.mark)
			self._app.logger:info('line "%s" unmarked [%s]', lnum, mark.mark)
			return true
		end
	end

	-- Mark the current line with the first available letter
	local chars = global and self._app.config.marks.globals or self._app.config.marks.locals
	for _, c in pairs(vim.split(chars, "")) do
		if not marks[c] then
			vim.cmd.mark(c)
			self._app.logger:info('line "%s" marked with [%s]', vim.fn.line("."), c)
			return true
		end
	end

	self._app.logger:warn("no more available marks")
	return false
end

--- Sort marks by the given field
---@param groups table
---@param func function
---@return table
local function sort_marks(groups, func)
	for _, group in pairs(groups) do
		table.sort(group, func)
	end
end

--- Return the list of both global and local marks
--- Only [a-z-A-Z] marks are returned
---@param bufnr integer
local function getmarklist(bufnr)
	local marks = {}
	local bufpath = vim.api.nvim_buf_get_name(bufnr)
	for _, mark in pairs(vim.list_extend(vim.fn.getmarklist(), vim.fn.getmarklist(bufnr))) do
		if string.match(mark.mark, "%a") then
			mark.mark = string.sub(mark.mark, 2) -- remove leading '
			if not mark.file then
				mark.file = bufpath
			else
				mark.file = vim.fn.fnamemodify(mark.file, ":p")
			end
			table.insert(marks, mark)
		end
	end
	return marks
end

--- Filter a single mark
---@param mark Mark
---@param context Context
---@return boolean
function Marklist:_filter(mark, context)
	if self._filter_func and not self._filter_func(mark, context) then
		return false
	end
	return true
end

--- Return marks grouped by the file they belong to
--- Retrieve the filtered mark list
---@param bufnr integer
---@return table
function Marklist:_get_marks(bufnr)
	local groups = {}
	for _, item in pairs(getmarklist(bufnr)) do
		local mark = Mark:new()
		mark.mark = item.mark
		mark.lnum = item.pos[2]
		mark.col = item.pos[3]
		mark.file = item.file
		mark.loaded = true
		if vim.fn.bufloaded(mark.file) == 0 then
			-- If the buffer is in the buffer list, load it anyway
			if not self._app.config.lazy_load_buffers or vim.fn.buflisted(mark.file) == 1 then
				vim.fn.bufload(vim.fn.bufadd(mark.file))
				mark.loaded = true
			else
				mark.loaded = false
			end
		end
		if mark.loaded then
			mark.line = vim.fn.getbufoneline(mark.file, mark.lnum)
		end
		if self:_filter(mark, self._app.context) then
			if not groups[mark.file] then
				groups[mark.file] = {}
			end
			table.insert(groups[mark.file], mark)
		end
	end
	local ok, err = pcall(sort_marks, groups, self._app.config.marks.sort_marks)
	if not ok then
		local msg = string.gsub(tostring(err), "^.*:%s+", "")
		self._app.logger:err("error while sorting marks: " .. msg)
		return {}
	end
	return groups
end

---Check that a mark has been already set
---@param mark string
---@return boolean
function Marklist:_mark_exists(mark)
	for _, group in pairs(self._marks) do
		for _, m in pairs(group) do
			if m.mark == mark then
				return true
			end
		end
	end
	return false
end

--- Move the cursor to the first mark of the current buffer or the the closest mark, if any
---@param map table
function Marklist:_set_cursor(map)
	if not map then
		return
	end

	local header_line, first_line
	local closest_line, closest_distance
	local bufpath = self._app.context.bufpath

	for i, item in pairs(map) do
		if not header_line and type(item) == "string" and item == bufpath then
			header_line = i
		elseif type(item) == "table" then
			if item.file == bufpath then
				if not first_line then
					first_line = i
				end
				local distance = math.abs(item.lnum - self._app.context.curpos[2])
				if
					not closest_distance
					or distance < closest_distance
						and distance < self._app.config.marks.proximity_threshold
				then
					closest_line = i
					closest_distance = distance
				end
			end
		end
	end

	if closest_line and self._app.config.marks.move_to_closest_mark then
		util.cursor(closest_line)
	elseif first_line and self._app.config.marks.move_to_first_mark then
		util.cursor(first_line)
	elseif header_line then
		util.cursor(header_line)
	else
		vim.fn.cursor(1, 1)
	end
end

--- Close the mark list window
function Marklist:_action_close()
	self._app:_close_window()
end

--- Jump to the mark on the current line
---@param mode integer
---@param map table
---@param keepjumps boolean
function Marklist:_action_jump(mode, map, keepjumps)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	self:_action_close()

	local keepj = keepjumps and "keepj " or ""

	if mode == util.modes.SPLIT then
		vim.cmd(keepj .. "split")
	elseif mode == util.modes.VSPLIT then
		vim.cmd(keepj .. "vsplit")
	elseif mode == util.modes.TAB then
		vim.cmd(keepj .. "tab split")
	end

	if type(selected) == "string" then
		local bufnr = vim.fn.bufnr(selected)
		if bufnr ~= -1 then
			vim.cmd(keepj .. "buffer " .. bufnr)
		else
			-- buffer is not loaded, use :edit instead
			vim.cmd(keepj .. "edit " .. vim.fn.fnameescape(selected))
		end
	else
		local type = self._app.config.marks.use_backtick and "`" or "'"
		vim.cmd(keepj .. "norm! " .. type .. selected.mark)
		if self._app.config.jump_callback then
			self._app.config.jump_callback(mode, self._app.context)
		end
		if self._app.config.highlight_on_jump then
			util.cursorline(self._app.config.highlight_timeout)
		end
	end
end

--- Unset the mark on the current line
---@param map table
function Marklist:_action_delete(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	local delmark = function(mark)
		vim.fn.win_execute(self._app.context.wininfo.winid, "delmarks " .. mark)
	end

	if type(selected) == "string" then
		-- selected line is a path header, remove all marks for this file
		for _, mark in pairs(map) do
			if selected == mark.file then
				delmark(mark.mark)
			end
		end
	else
		delmark(selected.mark)
	end

	self:_refresh()
end

--- Move to next/prev mark group
---@param map table
---@param backwards boolean
function Marklist:_action_next_group(map, backwards)
	local lnum = vim.fn.line(".")
	local current = map[lnum]
	local step = backwards and -1 or 1
	local stop = backwards and 1 or vim.fn.line("$")
	for i = lnum, stop, step do
		if type(map[i]) == "string" and map[i] ~= current then
			util.cursor(i, 1)
			break
		end
	end
end

--- Execute a mapping in the context of the "calling" window.
---@param mapping string
function Marklist:_action_passthrough(mapping)
	self:_action_close()
	local cmd = string.format('execute "normal! %s%s"', vim.v.count1, mapping)
	vim.fn.win_execute(self._app.context.wininfo.winid, cmd)
end

--- Allow jumping to marks with the classic '
--- Jumping to UPPERCASE marks would work without this function,
--- but for lowercase marks we need to execute the mapping in the context of the
--- current buffer
---@param map table
---@param typ string
---@param mark string
function Marklist:_action_jump_passthrough(map, typ, mark)
	for _, entry in pairs(map) do
		if type(entry) == "table" then
			if entry.mark == mark then
				self:_action_passthrough(typ .. entry.mark)
			end
		end
	end
end

--- Change mark on the current line
---@param map table
---@param mark string
function Marklist:_action_change_mark(map, mark)
	local selected = map[vim.fn.line(".")]
	if not selected or type(selected) == "string" then
		return
	end
	if self:_mark_exists(mark) then
		self._app.logger:err(string.format("mark '%s' already set, delete it first", mark))
		return
	end
	if selected.loaded then
		local mark_bufnr = vim.fn.bufnr(selected.file)
		if string.match(mark, "%l") and mark_bufnr ~= self._app.context.bufnr then
			self._app.logger:err("local marks can be set only for the current buffer")
			return
		end
		vim.fn.win_execute(self._app.context.wininfo.winid, "delmarks " .. selected.mark)
		vim.api.nvim_buf_set_mark(mark_bufnr, mark, selected.lnum, selected.col, {})
		self:_refresh()
	else
		self._app.logger:err("cannot change mark, buffer not loaded")
	end
end

--- Setup mappings for the mark window
---@param map table
function Marklist:_setup_mappings(map)
	util.keymap("n", self._app.config.marks.mappings.close, function()
		self:_action_close()
	end)
	util.keymap("n", self._app.config.marks.mappings.delete, function()
		self:_action_delete(map)
	end)
	util.keymap("n", self._app.config.marks.mappings.next_group, function()
		self:_action_next_group(map, false)
	end)
	util.keymap("n", self._app.config.marks.mappings.prev_group, function()
		self:_action_next_group(map, true)
	end)
	util.keymap("n", self._app.config.marks.mappings.jump, function()
		self:_action_jump(util.modes.BUFFER, map, false)
	end)
	util.keymap("n", self._app.config.marks.mappings.keepj_jump, function()
		self:_action_jump(util.modes.BUFFER, map, true)
	end)
	util.keymap("n", self._app.config.marks.mappings.tab, function()
		self:_action_jump(util.modes.TAB, map, false)
	end)
	util.keymap("n", self._app.config.marks.mappings.keepj_tab, function()
		self:_action_jump(util.modes.TAB, map, true)
	end)
	util.keymap("n", self._app.config.marks.mappings.split, function()
		self:_action_jump(util.modes.SPLIT, map, false)
	end)
	util.keymap("n", self._app.config.marks.mappings.keepj_split, function()
		self:_action_jump(util.modes.SPLIT, map, true)
	end)
	util.keymap("n", self._app.config.marks.mappings.vsplit, function()
		self:_action_jump(util.modes.VSPLIT, map, false)
	end)
	util.keymap("n", self._app.config.marks.mappings.keepj_vsplit, function()
		self:_action_jump(util.modes.VSPLIT, map, true)
	end)

	local marks = self._app.config.marks.globals .. self._app.config.marks.locals
	for _, mark in pairs(vim.split(marks, "")) do
		util.keymap("n", "m" .. mark, function()
			self:_action_change_mark(map, mark)
		end)
		util.keymap("n", "'" .. mark, function()
			self:_action_jump_passthrough(map, "'", mark)
		end)
		util.keymap("n", "`" .. mark, function()
			self:_action_jump_passthrough(map, "`", mark)
		end)
	end
end

--- Re-render the buffer with new marks
---@return table
function Marklist:_refresh()
	local line = vim.fn.line(".")
	self:init()
	local map = self:_render()
	util.vcursor(line, 1)
	return map
end

--- Render the marks
---@return table Table mapping each line to the mark displayed on it
function Marklist:_render()
	vim.fn.setbufvar(self._bufnr, "&modifiable", 1)
	-- Note: vim.fn.deletebufline(self._bufnr, 1, "$") produces an unwanted message
	vim.cmd('sil! keepj norm! gg"_dG')
	vim.api.nvim_buf_clear_namespace(self._bufnr, self._nsid, 1, -1)

	if next(self._marks) == nil then
		vim.fn.setbufline(self._bufnr, 1, self._app.config.marks.not_found)
		vim.fn.setbufvar(self._bufnr, "&modifiable", 0)
		self:_setup_mappings({})
		util.fit_content(self._app.config.window.max_height)
		return {}
	end

	local _, groups_count = self:get_count()

	local paths = vim.tbl_keys(self._marks)
	local ok, err = pcall(table.sort, paths, self._app.config.marks.sort_groups)
	if not ok then
		local msg = string.gsub(tostring(err), "^.*:%s+", "")
		self._app.logger:err("error while sorting groups: " .. msg)
		self._app:_close_window()
		return {}
	end

	local i = 0
	local map = {}

	for _, path in pairs(paths) do
		local group = self._marks[path]

		local ok, line, matches = pcall(self._app.config.marks.formatters.header, {
			file = path,
			cur_bufpath = self._app.context.bufpath,
			groups_count = groups_count,
		}, self._app.config)
		if not ok then
			self._app:_close_window()
			local msg = string.gsub(tostring(line), "^.*:%s+", "")
			self._app.logger:err("header formatter error: " .. msg)
			return {}
		end
		if line then
			i = i + 1
			map[i] = path
			vim.fn.setbufline(self._bufnr, i, line)
			if matches then
				util.set_matches(matches, i, self._bufnr, self._nsid)
			end
		end

		local max_lnum, max_col
		for _, mark in pairs(group) do
			if not max_lnum or mark.lnum > max_lnum then
				max_lnum = mark.lnum
			end
			if not max_col or mark.col > max_col then
				max_col = mark.col
			end
		end

		local k = 0
		for _, mark in ipairs(group) do
			k = k + 1
			ok, line, matches = pcall(self._app.config.marks.formatters.mark, {
				mark = mark,
				pos = k,
				is_last = k == #group,
				cur_bufpath = self._app.context.bufpath,
				groups_count = groups_count,
				max_group_lnum = max_lnum,
				max_group_col = max_col,
			}, self._app.config)
			if not ok then
				self._app:_close_window()
				local msg = string.gsub(tostring(line), "^.*:%s+", "")
				self._app.logger:err("mark formatter error: " .. msg)
				return {}
			end
			if line then
				i = i + 1
				map[i] = mark
				vim.fn.setbufline(self._bufnr, i, line)
				if matches then
					util.set_matches(matches, i, self._bufnr, self._nsid)
				end
			end
		end
	end

	vim.fn.setbufvar(self._bufnr, "&modifiable", 0)

	self:_setup_mappings(map)
	util.fit_content(self._app.config.window.max_height)
	self:_set_cursor(map)

	return map
end

return Marklist
