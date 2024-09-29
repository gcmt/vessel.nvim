---@module "jumplist"

local util = require("vessel.util")
local logger = require("vessel.logger")

---@class Jump
---@field current boolean
---@field pos integer
---@field relpos integer
---@field bufnr integer
---@field bufpath string
---@field lnum integer
---@field col integer
---@field line string
local Jump = {}
Jump.__index = Jump

--- Return a new Jump instance
---@return Jump
function Jump:new()
	local jump = {}
	setmetatable(jump, Jump)
	jump.current = false
	jump.pos = 0
	jump.relpos = 0
	jump.bufnr = -1
	jump.bufpath = ""
	jump.lnum = 0
	jump.col = 0
	jump.line = ""
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
	jumps._filter_func = filter_func
	return jumps
end

--- Initialize Jumplist
---@return Jumplist
function Jumplist:init()
	self._jumps = self:_get_jumps()
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

	if selected.relpos == 0 then
		vim.cmd("keepj buffer " .. selected.bufnr)
		util.vcursor(selected.lnum, selected.col)
	else
		local cmd = selected.relpos < 0 and "\\<c-o>" or "\\<c-i>"
		vim.cmd(string.format('exec "norm! %s%s"', math.abs(selected.relpos), cmd))
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

--- Return the real count
--- When config.real_positions == false, the count relative to the current position
--- is translated to the actual position in the jump list of the targeted jump
---@param map table
---@param count integer
---@param mapping string
---@return integer
function Jumplist:_get_real_count(map, count, mapping)
	local line = 0
	for i = 1, vim.fn.line("$") do
		if map[i] and map[i].current then
			line = i
			break
		end
	end
	mapping = string.gsub(mapping, "\\", "")
	if mapping == self._app.config.jumps.mappings.ctrl_o then
		line = line + count
	elseif mapping == self._app.config.jumps.mappings.ctrl_i then
		line = line - count
	end
	if line < 1 or line > vim.fn.line("$") then
		error(string.format("invalid count (out of bound): %s", count), 2)
	end
	return math.abs(map[line].relpos)
end

--- Execute a mapping in the context of the calling window.
--- Why: executing <c-o> and <c-i> from the jumplist window does not work as
--- expected as a new jump is being added to the jumplist due to the fact that
--- we opened a new floating window with a new buffer
---@param map table
---@param mapping string
function Jumplist:_action_passthrough(map, mapping)
	local count = vim.v.count1
	if not self._app.config.jumps.real_positions then
		local ok, val = pcall(Jumplist._get_real_count, self, map, count, mapping)
		if not ok then
			logger.warn(val)
			return
		end
		count = val
	end
	self:_action_close()
	local cmd = string.format('execute "normal! %s%s"', count, mapping)
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
	util.keymap("n", self._app.config.jumps.mappings.ctrl_o, function(mapping)
		local ctrl_o = string.gsub(mapping, "%b<>", "\\%1")
		self:_action_passthrough(map, ctrl_o)
	end)
	util.keymap("n", self._app.config.jumps.mappings.ctrl_i, function(mapping)
		local ctrl_i = string.gsub(mapping, "%b<>", "\\%1")
		self:_action_passthrough(map, ctrl_i)
	end)
	util.keymap("n", self._app.config.jumps.mappings.jump, function()
		self:_action_jump(util.modes.BUFFER, map)
	end)
end

--- Retrieve the jump list (reversed)
---@return table
function Jumplist:_get_jumps()
	local jumps = {}
	-- when not currently traversing th jump,list with ctrl-o or ctrl-i,
	-- #len == _curpos, otherwise '_curpos' is a valid 'list' index
	local list, _curpos = unpack(vim.fn.getjumplist(self._app.context.wininfo.winid))
	local len = #list
	local curpos = math.max(len - _curpos, 1)

	for i, j in ipairs(list) do
		local jump = Jump:new()
		jump.current = len - i + 1 == curpos
		-- jump.pos is the position in the real jumplist
		jump.pos = len + 1 - i
		-- position relative to the current jump position
		jump.relpos = len == _curpos and -jump.pos or curpos - jump.pos
		jump.bufnr = j.bufnr
		jump.line = ""
		jump.lnum = j.lnum
		jump.col = j.col

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
			if self:_filter(jump, self._app.context) or curpos == jump.pos then
				table.insert(jumps, jump)
			end
		end

		::continue::
	end

	-- most recent first
	table.sort(jumps, function(a, b)
		return a.pos < b.pos
	end)

	return jumps
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
	vim.cmd('sil! keepj norm! gg"_dG')
	vim.api.nvim_buf_clear_namespace(self._bufnr, self._nsid, 1, -1)

	if #self._jumps == 0 then
		vim.fn.setbufline(self._bufnr, 1, self._app.config.jumps.not_found)
		vim.fn.setbufvar(self._bufnr, "&modifiable", 0)
		self:_setup_mappings({})
		util.fit_content(self._app.config.window.max_height)
		return {}
	end

	local map = {}
	local jump_formatter = self._app.config.jumps.formatters.jump
	local jumps_count = #self._jumps
	local current_jump_line
	local max_basename
	local max_suffix
	local max_lnum
	local max_col
	local max_relpos

	local paths = {}
	for _, jump in pairs(self._jumps) do
		table.insert(paths, jump.bufpath)
	end

	-- find for each path the shortest unique suffix
	local suffixes = util.unique_suffixes(paths)
	for _, suffix in pairs(suffixes) do
		local suffix_len = vim.fn.strchars(suffix)
		if not max_suffix or suffix_len > max_suffix then
			max_suffix = suffix_len
		end
	end

	for i, jump in ipairs(self._jumps) do
		if jump.current then
			current_jump_line = i
		end
		if not max_lnum or jump.lnum > max_lnum then
			max_lnum = jump.lnum
		end
		if not max_col or jump.col > max_col then
			max_col = jump.col
		end
		local rel = math.abs(jump.relpos)
		if not max_relpos or rel > max_relpos then
			max_relpos = rel
		end
		local basename = vim.fn.strchars(vim.fs.basename(jump.bufpath))
		if not max_basename or basename > max_basename then
			max_basename = basename
		end
	end

	local i = 0
	for _, jump in ipairs(self._jumps) do
		i = i + 1
		local ok, line, matches = pcall(jump_formatter, jump, {
			current_line = i,
			current_jump_line = current_jump_line,
			jumps_count = jumps_count,
			max_lnum = max_lnum,
			max_col = max_col,
			max_relpos = max_relpos,
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
		map[i] = jump
		vim.fn.setbufline(self._bufnr, i, line)
		if matches then
			util.set_matches(matches, i, self._bufnr, self._nsid)
		end
	end

	vim.fn.setbufvar(self._bufnr, "&modifiable", 0)

	self:_setup_mappings(map)
	util.fit_content(self._app.config.window.max_height)
	util.cursor(current_jump_line)

	return map
end

return Jumplist
