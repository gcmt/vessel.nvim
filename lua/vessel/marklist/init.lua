---@module "marklist"

local BufWriter = require("vessel.bufwriter")
local Context = require("vessel.context")
local FileStore = require("vessel.filestore")
local Window = require("vessel.window")
local help = require("vessel.help")
local logger = require("vessel.logger")
local util = require("vessel.util")

-- Stateful sort type
local SORT_FUNC

---@class Mark
---@field mark string Mark letter
---@field lnum integer Mark line number
---@field col integer Mark column number
---@field line string? Line on which the mark is positioned
---@field file string File the mark belongs to
---@field err string? Why the mark is invalid
local Mark = {}
Mark.__index = Mark

--- Return a new Mark instance
---@param letter string
---@return Mark
function Mark:new(letter)
	local mark = {}
	setmetatable(mark, Mark)
	mark.mark = letter or ""
	mark.lnum = 0
	mark.col = 0
	mark.line = nil
	mark.file = ""
	mark.err = nil
	return mark
end

---@class Marklist
---@field bufft string Buffer filetype
---@field config table Gloabl config
---@field context Context Info about the current buffer/window
---@field window Window The main popup window
---@field filestore FileStore File cache
---@field bufnr integer Buffer where marks will be displayed
---@field marks table Marks grouped by file
---@field filter_func function?
local Marklist = {}
Marklist.__index = Marklist

--- Return a new Marklist instance
---@param config table
---@param filter_func function?
---@return Marklist
function Marklist:new(config, filter_func)
	local marks = {}
	setmetatable(marks, Marklist)
	marks.bufft = "marklist"
	marks.config = config
	marks.context = Context:new()
	marks.window = Window:new(config, marks.context)
	marks.filestore = FileStore:new()
	marks.bufnr = -1
	marks.marks = {}
	marks.filter_func = filter_func
	return marks
end

--- Initialize Markslist
---@return Marklist
function Marklist:init()
	self.marks = self:_get_marks(self.context.bufnr)
	return self
end

--- Open the window and render the content
function Marklist:open()
	self:init()
	local bufnr, ok = self.window:open(self:_get_count(), self.config.marks.preview)
	if ok then
		self.bufnr = bufnr
		vim.fn.setbufvar(bufnr, "&filetype", self.bufft)
		vim.cmd("doau User VesselMarklistEnter")
		self:_set_cursor(self:_render())
	end
end

--- Return total marks and groups count
---@return integer
function Marklist:_get_count()
	local marks_count, groups_count = 0, 0
	for _, group in pairs(self.marks) do
		groups_count = groups_count + 1
		marks_count = marks_count + #group
	end
	return marks_count + groups_count
end

--- Set a mark on the current line by choosing a letter automatically.
--- If the mark is already set, then it is deleted, Unless the 'toggle_mark'
--- option is set to false.
---@param global boolean Whether or not the mark should be global
---@return boolean
function Marklist:set_mark(global)
	local lnum = self.context.curpos[2]
	local bufpath = self.context.bufpath

	local marks = {}
	for _, group in pairs(self.marks) do
		for _, m in pairs(group) do
			marks[m.mark] = m
		end
	end

	-- Check if the mark is already set on the current line and if so, delete it
	for _, mark in pairs(marks) do
		if mark.file == bufpath and mark.lnum == lnum then
			if not self.config.marks.toggle_mark then
				logger.info('line "%s" already marked with [%s]', lnum, mark.mark)
				return false
			end
			vim.cmd.delmarks(mark.mark)
			logger.info('line "%s" unmarked [%s]', lnum, mark.mark)
			return true
		end
	end

	-- Mark the current line with the first available letter
	local chars = global and self.config.marks.globals or self.config.marks.locals
	for _, c in pairs(vim.split(chars, "")) do
		if not marks[c] then
			vim.cmd.mark(c)
			logger.info('line "%s" marked with [%s]', vim.fn.line("."), c)
			return true
		end
	end

	logger.warn("no more available marks")
	return false
end

--- Sort marks by the given field
---@param groups table
---@param func function
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
	if self.filter_func and not self.filter_func(mark, context) then
		return false
	end
	return true
end

--- Return marks grouped by the file they belong to
--- Retrieve the filtered mark list
---@param bufnr integer
---@return table
function Marklist:_get_marks(bufnr)
	local max_lnums = {}
	local marks = {}
	for _, item in pairs(getmarklist(bufnr)) do
		local mark = Mark:new(item.mark)
		mark.lnum = item.pos[2]
		mark.col = item.pos[3]
		mark.file = item.file
		table.insert(marks, mark)
		-- calculate max lnum per file in order to load files for efficiently
		if not max_lnums[mark.file] or mark.lnum > max_lnums[mark.file] then
			max_lnums[mark.file] = mark.lnum + vim.o.lines
		end
	end

	local groups = {}
	for _, mark in pairs(marks) do
		local lines, err = self.filestore:store(mark.file, max_lnums[mark.file])
		if lines then
			mark.line, mark.err = self.filestore:getline(mark.file, mark.lnum)
		else
			mark.err = err
		end
		if self:_filter(mark, self.context) then
			if not groups[mark.file] then
				groups[mark.file] = {}
			end
			table.insert(groups[mark.file], mark)
		end
	end

	local sort_func = SORT_FUNC or self.config.marks.sort_marks[1]
	local func, description = sort_func()
	local ok, err = pcall(sort_marks, groups, func)
	if not ok then
		local msg = string.gsub(tostring(err), "^.*:%s+", "")
		logger.err("marks sorting error: %s", msg)
		return {}
	elseif SORT_FUNC and description ~= "" then
		-- give feedback only if SORT_FUNC gets changed
		logger.info("vessel: %s", description)
	end

	return groups
end

---Check that a mark has been already set
---@param mark string
---@return boolean
function Marklist:_mark_exists(mark)
	for _, group in pairs(self.marks) do
		for _, m in pairs(group) do
			if m.mark == mark then
				return true
			end
		end
	end
	return false
end

--- Keep cursor on selected mark
---@param selected Mark Selected mark
---@param map table New map table
function Marklist:_follow_selected(selected, map)
	for i, item in pairs(map) do
		if
			type(item) == "string" and type(selected) == "string" and item == selected
			or type(item) == "table"
				and type(selected) == "table"
				and item.mark == selected.mark
		then
			util.vcursor(i)
			break
		end
	end
end

--- Move the cursor to the first mark of the current buffer or the the closest mark, if any
--- Used just after the windows opens up
---@param map table
function Marklist:_set_cursor(map)
	if not map then
		return
	end

	local header_line, first_line
	local closest_line, closest_distance
	local bufpath = self.context.bufpath

	for i, item in pairs(map) do
		if not header_line and type(item) == "string" and item == bufpath then
			header_line = i
		elseif type(item) == "table" then
			if item.file == bufpath then
				if not first_line then
					first_line = i
				end
				local distance = math.abs(item.lnum - self.context.curpos[2])
				if
					not closest_distance
					or distance < closest_distance
						and distance < self.config.marks.proximity_threshold
				then
					closest_line = i
					closest_distance = distance
				end
			end
		end
	end

	if closest_line and self.config.marks.move_to_closest_mark then
		util.cursor(closest_line)
	elseif first_line and self.config.marks.move_to_first_mark then
		util.cursor(first_line)
	elseif header_line then
		util.cursor(header_line)
	else
		vim.fn.cursor(1, 1)
	end
end

--- Execute post jump actions
---@param mode integer
function Marklist:_post_jump_cb(mode)
	if self.config.jump_callback then
		self.config.jump_callback(mode, self.context)
	end
	if self.config.highlight_on_jump then
		util.cursorline(self.config.highlight_timeout)
	end
end

--- Close the mark list window
function Marklist:_action_close()
	self.window:_close_window()
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

	if selected.err then
		logger.err(selected.err)
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
		local type = self.config.marks.use_backtick and "`" or "'"
		local ok, err = pcall(vim.cmd, keepj .. "norm! " .. type .. selected.mark)
		if not ok then
			logger.err(string.gsub(err, "^.*Vim%(%a+%):", ""))
			return
		end
		self:_post_jump_cb(mode)
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
		vim.fn.win_execute(self.context.wininfo.winid, "delmarks " .. mark)
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
	vim.fn.win_execute(self.context.wininfo.winid, cmd)
	self:_post_jump_cb(util.modes.BUFFER)
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
		logger.err("mark '%s' already set, delete it first", mark)
		return
	end
	if selected.loaded then
		local mark_bufnr = vim.fn.bufnr(selected.file)
		if string.match(mark, "%l") and mark_bufnr ~= self.context.bufnr then
			logger.err("local marks can be set only for the current buffer")
			return
		end
		vim.fn.win_execute(self.context.wininfo.winid, "delmarks " .. selected.mark)
		vim.api.nvim_buf_set_mark(mark_bufnr, mark, selected.lnum, selected.col, {})
		local newmap = self:_refresh()
		self:_follow_selected(Mark:new(mark), newmap)
	else
		logger.err("cannot change mark, buffer not loaded")
	end
end

--- Cycle sort functions
---@param map table
function Marklist:_action_cycle_sort(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	local funcs = self.config.marks.sort_marks
	local index = 1
	for i = 1, #funcs do
		if SORT_FUNC == funcs[i] then
			index = i
			break
		end
	end

	SORT_FUNC = funcs[(index % #funcs) + 1]
	local newmap = self:_refresh()
	self:_follow_selected(selected, newmap)
end

--- Render help inside the window
---@param map table
function Marklist:_action_show_help(map)
	for k in pairs(map) do
		map[k] = nil
	end
	local function close_handler()
		self:_render()
	end
	help.render(
		self.bufnr,
		"Mark list help",
		self.config.marks.mappings,
		require("vessel.marklist.helptext"),
		close_handler
	)
	self.window:fit_content()
end

--- Setup mappings for the mark window
---@param map table
function Marklist:_setup_mappings(map)
	util.keymap("n", self.config.help_key, function()
		self:_action_show_help(map)
	end)
	util.keymap("n", self.config.marks.mappings.cycle_sort, function()
		self:_action_cycle_sort(map)
	end)
	util.keymap("n", self.config.marks.mappings.close, function()
		self:_action_close()
	end)
	util.keymap("n", self.config.marks.mappings.delete, function()
		self:_action_delete(map)
	end)
	util.keymap("n", self.config.marks.mappings.next_group, function()
		self:_action_next_group(map, false)
	end)
	util.keymap("n", self.config.marks.mappings.prev_group, function()
		self:_action_next_group(map, true)
	end)
	util.keymap("n", self.config.marks.mappings.jump, function()
		self:_action_jump(util.modes.BUFFER, map, false)
	end)
	util.keymap("n", self.config.marks.mappings.keepj_jump, function()
		self:_action_jump(util.modes.BUFFER, map, true)
	end)
	util.keymap("n", self.config.marks.mappings.tab, function()
		self:_action_jump(util.modes.TAB, map, false)
	end)
	util.keymap("n", self.config.marks.mappings.keepj_tab, function()
		self:_action_jump(util.modes.TAB, map, true)
	end)
	util.keymap("n", self.config.marks.mappings.split, function()
		self:_action_jump(util.modes.SPLIT, map, false)
	end)
	util.keymap("n", self.config.marks.mappings.keepj_split, function()
		self:_action_jump(util.modes.SPLIT, map, true)
	end)
	util.keymap("n", self.config.marks.mappings.vsplit, function()
		self:_action_jump(util.modes.VSPLIT, map, false)
	end)
	util.keymap("n", self.config.marks.mappings.keepj_vsplit, function()
		self:_action_jump(util.modes.VSPLIT, map, true)
	end)

	local marks = self.config.marks.globals .. self.config.marks.locals
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

--- Get metadata tables for all marka and each group
---@param marks Marklist
---@return table, table
function Marklist:_get_meta(marks)
	local meta = {
		max_col = 0,
		max_lnum = 0,
		groups_count = 0,
		-- Maps each path the its shortest unique suffix
		suffixes = {},
		max_suffix = 0,
	}

	local paths = {}
	local groups_meta = {}

	for path, group in pairs(self.marks) do
		groups_meta[path] = {}
		table.insert(paths, path)
		meta.groups_count = meta.groups_count + 1
		for _, mark in pairs(group) do
			if not meta.max_lnum or mark.lnum > meta.max_lnum then
				meta.max_lnum = mark.lnum
			end
			if not meta.max_col or mark.col > meta.max_col then
				meta.max_col = mark.col
			end
			if not groups_meta[path].max_col or mark.col > groups_meta[path].max_col then
				groups_meta[path].max_col = mark.col
			end
			if not groups_meta[path].max_lnum or mark.lnum > groups_meta[path].max_lnum then
				groups_meta[path].max_lnum = mark.lnum
			end
		end
	end

	meta.suffixes = util.unique_suffixes(paths)
	for _, suffix in pairs(meta.suffixes) do
		local suffix_len = vim.fn.strchars(suffix)
		if not meta.max_suffix or suffix_len > meta.max_suffix then
			meta.max_suffix = suffix_len
		end
	end

	return meta, groups_meta
end

--- Render the marks
---@return table Table mapping each line to the mark displayed on it
function Marklist:_render()
	local bufwriter = BufWriter:new(self.bufnr):init()
	local preview_aug = vim.api.nvim_create_augroup("VesselPreview", { clear = true })

	if next(self.marks) == nil then
		bufwriter:append(self.config.marks.not_found):freeze()
		self.window:fit_content()
		self:_setup_mappings({})
		self.window:_set_buffer_data({})
		vim.cmd("doau User VesselMarklistChanged")
		self.window.preview:clear()
		return {}
	end

	local paths = vim.tbl_keys(self.marks)
	local ok, err = pcall(table.sort, paths, self.config.marks.sort_groups)
	if not ok then
		local msg = string.gsub(tostring(err), "^.*:%s+", "")
		logger.err("error while sorting groups: %s", msg)
		self.window:_close_window()
		return {}
	end

	local map = {}
	local meta, groups_meta = self:_get_meta(self.marks)

	local mark_formatter = self.config.marks.formatters.mark
	local header_formatter = self.config.marks.formatters.header

	for _, path in pairs(paths) do
		local group = self.marks[path]

		local ok, line, matches = pcall(header_formatter, path, {
			groups_count = meta.groups_count,
			suffixes = meta.suffixes,
			max_suffix = meta.max_suffix,
		}, self.context, self.config)
		if not ok then
			self.window:_close_window()
			local msg = string.gsub(tostring(line), "^.*:%s+", "")
			logger.err("header formatter error: %s", msg)
			return {}
		end
		if line then
			bufwriter:append(line, matches)
			map[bufwriter.lnum] = path
		end

		local k = 0
		for _, mark in ipairs(group) do
			k = k + 1
			ok, line, matches = pcall(mark_formatter, mark, {
				pos = k,
				is_last = k == #group,
				groups_count = meta.groups_count,
				max_lnum = meta.max_lnum,
				max_col = meta.max_col,
				max_group_lnum = groups_meta[path].max_lnum,
				max_group_col = groups_meta[path].max_col,
				suffixes = meta.suffixes,
				max_suffix = meta.max_suffix,
			}, self.context, self.config)
			if not ok or not line then
				local msg
				if not line then
					msg = string.format("line %s: string expected, got nil", bufwriter.lnum)
				else
					msg = string.gsub(tostring(line), "^.*:%s+", "")
				end
				self.window:_close_window()
				logger.err("formatter error: %s", msg)
				return {}
			end
			bufwriter:append(line, matches)
			map[bufwriter.lnum] = mark
		end
	end

	bufwriter:freeze()
	self.window:fit_content()
	self:_setup_mappings(map)
	self.window:_set_buffer_data(map)
	vim.cmd("doau User VesselMarklistChanged")

	if self.window.preview.bufnr ~= -1 then
		-- Show the file under cursor content in the preview popup
		vim.api.nvim_create_autocmd("CursorMoved", {
			desc = "Write to the preview window on every movement",
			group = preview_aug,
			buffer = self.bufnr,
			callback = function()
				local mark = map[vim.fn.line(".")]
				if mark then
					local file = type(mark) == "table" and mark.file or mark
					local lnum = type(mark) == "table" and mark.lnum or 1
					self.window.preview:show(self.filestore, file, lnum)
				end
			end,
		})
	end

	return map
end

return Marklist
