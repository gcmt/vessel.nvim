---@module "jumplist"

local util = require("vessel.util")

---@class Jump
---@field pos integer
---@field rel integer
---@field bufnr integer
---@field bufpath string
---@field lnum integer
---@field col integer
---@field line string
---@field loaded boolean
local Jump = {}
Jump.__index = Jump

--- Return a new Jump instance
---@return Jump
function Jump:new()
	local jump = {}
	setmetatable(jump, Jump)
	jump.pos = 0
	jump.rel = 0
	jump.bufnr = -1
	jump.bufpath = ""
	jump.lnum = 0
	jump.col = 0
	jump.line = ""
	jump.loaded = false
	return jump
end

--- Notes:
---
--- The jumplist and the jump position are reversed from what returned from
--- getjumplist()
---
--- getjumplist() returns a list of jumps with the last item being the most
--- recent jump. We display the list differently from :jumps, most recent at
--- the top.
---
--- If <c-o> or <c-i> have not been used, we consider the current jump postion to be 1,
--- even though getjumplist() returns the last jumplist index + 1, that is, len(getjumplist()).
---
---@class Jumplist
---@field _nsid integer Namespace id for highlighting
---@field _app App Reference to the main app
---@field _bufnr integer Where jumps will be rendered
---@field _jumps table Jumps list (unfiltered)
---@field _curpos integer Current postion in the jumplist
---@field _filter_func function?
local Jumplist = {}
Jumplist.__index = Jumplist

--- Return a new Jumplist instance
---@param app App
---@param filter_func function?
---@return Jumplist
function Jumplist:new(app, filter_func)
	local jumps = {}
	setmetatable(jumps, Jumplist)
	jumps._nsid = vim.api.nvim_create_namespace("__vessel__")
	jumps._app = app
	jumps._bufnr = -1
	jumps._jumps = {}
	jumps._curpos = 0
	jumps._filter_func = filter_func
	return jumps
end

--- Initialize Jumplist
---@return Jumplist
function Jumplist:init()
	self._jumps, self._curpos = self:_get_jumps()
	return self
end

--- Open the window and render the content
function Jumplist:open()
	self:init()
	local ok
	self._bufnr, ok = self._app:open_window(self)
	if ok then
		self:_render()
	end
end

--- Return total jumps count
---@return integer, integer
function Jumplist:get_count()
	return #self._jumps, 1
end

--- Close the jump list window
function Jumplist:_action_close()
	self._app:_close_window()
end

--- Jump to the jump entry on the current line
---@param mode integer
---@param map table
function Jumplist:_action_jump(mode, map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	self:_action_close()

	if selected.rel == 0 then
		vim.cmd("keepj buffer " .. selected.bufnr)
		util.vcursor(selected.lnum, selected.col)
	else
		local cmd = selected.rel < 0 and "\\<c-o>" or "\\<c-i>"
		vim.cmd(string.format('exec "norm! %s%s"', math.abs(selected.rel), cmd))
	end

	if self._app.config.jump_callback then
		self._app.config.jump_callback(mode, self._app.context)
	end
	if self._app.config.highlight_on_jump then
		util.cursorline(self._app.config.highlight_timeout)
	end
end

--- Clear all jumps for the current window
function Jumplist:_action_clear(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end
	vim.fn.win_execute(self._app.context.wininfo.winid, "clearjumps")
	self:_refresh()
end

--- Execute a mapping in the context of the calling window.
--- Why: executing <c-o> and <c-i> from the jumplist window does not work as
--- expected as a new jump is being added to the jumplist due to the fact that
--- we opened a new floating window with a new buffer
---
---@param mapping string
function Jumplist:_action_passthrough(mapping)
	self:_action_close()
	local cmd = string.format('execute "normal! %s%s"', vim.v.count1, mapping)
	vim.fn.win_execute(self._app.context.wininfo.winid, cmd)
end

--- Setup mappings for the jumplist window
---@param map table
function Jumplist:_setup_mappings(map)
	util.keymap("n", self._app.config.jumps.mappings.close, function()
		self:_action_close()
	end)
	util.keymap("n", self._app.config.jumps.mappings.clear, function()
		self:_action_clear(map)
	end)
	util.keymap("n", self._app.config.jumps.mappings.ctrl_o, function()
		self:_action_passthrough("\\<c-o>")
	end)
	util.keymap("n", self._app.config.jumps.mappings.ctrl_i, function()
		self:_action_passthrough("\\<c-i>")
	end)
	util.keymap("n", self._app.config.jumps.mappings.jump, function()
		self:_action_jump(util.modes.BUFFER, map)
	end)
end

--- Retrun the jumplist and the last used jump position in the list
--- Both list and position are reversed
---@return table, integer
function Jumplist:_get_jumps()
	local winid = self._app.context.wininfo.winid
	local jumps = {}
	local list, curpos = unpack(vim.fn.getjumplist(winid))
	local len = #list
	-- when outside jumplist, #len == pos
	local pos = math.max(len - curpos, 1)

	for i, j in ipairs(list) do
		local jump = Jump:new()
		jump.pos = len + 1 - i
		jump.rel = len == curpos and -jump.pos or pos - jump.pos
		jump.bufnr = j.bufnr
		jump.line = ""
		jump.lnum = j.lnum
		jump.col = j.col
		jump.loaded = true

		-- both nvim_buf_get_name() and bufload() fail if buffer does not exist
		if vim.fn.bufexists(j.bufnr) == 0 then
			goto continue
		end

		-- buffers are already added to the buffer list as soon as you execute
		-- :jumps or call getjumplist(), might as well load anyway
		vim.fn.bufload(jump.bufnr)
		jump.bufpath = vim.api.nvim_buf_get_name(j.bufnr)

		-- getbufline() returns empty table for invalid (out of bound) lines
		local line = vim.fn.getbufline(jump.bufnr, jump.lnum)
		if #line == 1 then
			jump.line = line[1]
			if self:_filter(jump, self._app.context) or pos == jump.pos then
				table.insert(jumps, jump)
			end
		end

		::continue::
	end

	-- most recent first
	table.sort(jumps, function(a, b)
		return a.pos < b.pos
	end)

	return jumps, pos
end

--- Filter a single jump
---@param jump Jump
---@param context Context
---@return boolean
function Jumplist:_filter(jump, context)
	if self._app.config.jumps.filter_empty_lines and vim.trim(jump.line) == "" then
		return false
	end
	if self._filter_func and not self._filter_func(jump, context) then
		return false
	end
	return true
end

--- Re-render the buffer with new jumps
---@return table
function Jumplist:_refresh()
	local line = vim.fn.line(".")
	self:init()
	local map = self:_render()
	util.vcursor(line, 1)
	return map
end

--- Render the jump list in the given buffer
---@return table Table mapping each line to the jump displayed on it
function Jumplist:_render()
	vim.fn.setbufvar(self._bufnr, "&modifiable", 1)
	-- Note: vim.fn.deletebufline(self._bufnr, 1, "$") produces an unwanted message
	vim.cmd('sil! keepj norm! gg"_dG')
	vim.api.nvim_buf_clear_namespace(self._bufnr, self._nsid, 1, -1)

	if #self._jumps == 0 then
		vim.fn.setbufline(self._bufnr, 1, self._app.config.jumps.not_found)
		vim.fn.setbufvar(self._bufnr, "&modifiable", 0)
		self:_setup_mappings({})
		util.fit_content(self._app.config.window.max_height)
		return {}
	end

	local paths = {}
	for _, jump in pairs(self._jumps) do
		table.insert(paths, jump.bufpath)
	end

	-- find for each path the shortest unique suffix
	local uniques = util.find_uniques(paths)
	local max_unique
	for _, unique in pairs(uniques) do
		local unique_len = vim.fn.strchars(unique)
		if not max_unique or unique_len > max_unique then
			max_unique = unique_len
		end
	end

	local i = 0
	local map = {}
	local cursor_line = 1
	local jump_formatter = self._app.config.jumps.formatters.jump

	local max_basename
	local max_lnum, max_col, max_rel

	for _, jump in ipairs(self._jumps) do
		if not max_lnum or jump.lnum > max_lnum then
			max_lnum = jump.lnum
		end
		if not max_col or jump.col > max_col then
			max_col = jump.col
		end
		local rel = math.abs(jump.rel)
		if not max_rel or rel > max_rel then
			max_rel = rel
		end
		local basename = vim.fn.strchars(vim.fs.basename(jump.bufpath))
		if not max_basename or basename > max_basename then
			max_basename = basename
		end
	end

	for _, jump in ipairs(self._jumps) do
		local ok, line, matches = pcall(jump_formatter, jump, {
			max_lnum = max_lnum,
			max_col = max_col,
			max_rel = max_rel,
			max_basename = max_basename,
			max_unique = max_unique,
			uniques = uniques,
			current_pos = self._curpos,
		}, self._app.context, self._app.config)
		if not ok then
			self._app:_close_window()
			local msg = string.gsub(tostring(line), "^.*:%s+", "")
			self._app.logger:err("jump formatter error: " .. msg)
			return {}
		end
		if line then
			i = i + 1
			map[i] = jump
			vim.fn.setbufline(self._bufnr, i, line)
			if matches then
				util.set_matches(matches, i, self._bufnr, self._nsid)
			end
			if self._curpos == jump.pos then
				cursor_line = i
			end
		end
	end

	vim.fn.setbufvar(self._bufnr, "&modifiable", 0)

	self:_setup_mappings(map)
	util.fit_content(self._app.config.window.max_height)
	util.cursor(cursor_line)

	return map
end

return Jumplist
