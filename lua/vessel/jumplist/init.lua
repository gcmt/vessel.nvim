---@module "jumplist
local Context = require("vessel.context")
local FileStore = require("vessel.filestore")
local Window = require("vessel.window")
local logger = require("vessel.logger")
local util = require("vessel.util")

---@class Jump
---@field current boolean
---@field pos integer
---@field relpos integer
---@field bufnr integer
---@field bufpath string
---@field lnum integer
---@field col integer
---@field line? string
---@field err? string
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
	jump.line = nil
	jump.err = nil
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
---@field nsid integer Namespace id for highlighting
---@field bufft string Buffer filetype
---@field config table Gloabl config
---@field context Context Info about the current buffer/window
---@field window Window The main popup window
---@field filestore FileStore File cache
---@field bufnr integer Where jumps will be displayed
---@field jumps table Jumps list
---@field filter_func function?
local Jumplist = {}
Jumplist.__index = Jumplist

--- Return a new Jumplist instance
---@param config table
---@param filter_func function?
---@return Jumplist
function Jumplist:new(config, filter_func)
	local jumps = {}
	setmetatable(jumps, Jumplist)
	jumps.nsid = vim.api.nvim_create_namespace("__vessel__")
	jumps.bufft = "jumplist"
	jumps.config = config
	jumps.context = Context:new()
	jumps.window = Window:new(config, jumps.context)
	jumps.filestore = FileStore:new()
	jumps.bufnr = -1
	jumps.jumps = {}
	jumps.filter_func = filter_func
	return jumps
end

--- Initialize Jumplist
---@return Jumplist
function Jumplist:init()
	self.jumps = self:_get_jumps()
	return self
end

--- Open the window and render the content
function Jumplist:open()
	self:init()
	local bufnr, ok = self.window:open(#self.jumps, self.config.jumps.preview)
	if ok then
		self.bufnr = bufnr
		vim.fn.setbufvar(bufnr, "&filetype", self.bufft)
		vim.cmd("doau User VesselJumplistEnter")
		self:_render()
	end
end

--- Close the jump list window
function Jumplist:_action_close()
	self.window:_close_window()
end

--- Execute post jump actions
---@param mode integer
function Jumplist:_post_jump_cb(mode)
	if self.config.jump_callback then
		self.config.jump_callback(mode, self.context)
	end
	if self.config.highlight_on_jump then
		util.cursorline(self.config.highlight_timeout)
	end
end

--- Jump to the jump entry on the current line
---@param mode integer
---@param map table
function Jumplist:_action_jump(mode, map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end

	if selected.err then
		logger.err(selected.err)
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

	self:_post_jump_cb(mode)
end

--- Clear all jumps for the current window
function Jumplist:_action_clear(map)
	local selected = map[vim.fn.line(".")]
	if not selected then
		return
	end
	vim.fn.win_execute(self.context.wininfo.winid, "clearjumps")
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
	if mapping == self.config.jumps.mappings.ctrl_o then
		line = line + count
	elseif mapping == self.config.jumps.mappings.ctrl_i then
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
	if not self.config.jumps.real_positions then
		local ok, val = pcall(Jumplist._get_real_count, self, map, count, mapping)
		if not ok then
			logger.warn(val)
			return
		end
		count = val
	end
	self:_action_close()
	local cmd = string.format('execute "normal! %s%s"', count, mapping)
	vim.fn.win_execute(self.context.wininfo.winid, cmd)
	self:_post_jump_cb(util.modes.BUFFER)
end

--- Setup mappings for the jumplist window
---@param map table
function Jumplist:_setup_mappings(map)
	util.keymap("n", self.config.jumps.mappings.close, function()
		self:_action_close()
	end)
	util.keymap("n", self.config.jumps.mappings.clear, function()
		self:_action_clear(map)
	end)
	util.keymap("n", self.config.jumps.mappings.ctrl_o, function(mapping)
		local ctrl_o = string.gsub(mapping, "%b<>", "\\%1")
		self:_action_passthrough(map, ctrl_o)
	end)
	util.keymap("n", self.config.jumps.mappings.ctrl_i, function(mapping)
		local ctrl_i = string.gsub(mapping, "%b<>", "\\%1")
		self:_action_passthrough(map, ctrl_i)
	end)
	util.keymap("n", self.config.jumps.mappings.jump, function()
		self:_action_jump(util.modes.BUFFER, map)
	end)
end

--- Retrieve the jump list (reversed)
---@return table
function Jumplist:_get_jumps()
	-- when not currently traversing th jump,list with ctrl-o or ctrl-i,
	-- #len == _curpos, otherwise '_curpos' is a valid 'list' index
	local list, _curpos = unpack(vim.fn.getjumplist(self.context.wininfo.winid))
	local len = #list
	local curpos = math.max(len - _curpos, 1)
	local max_lnums = {}

	local _jumps = {}
	for i, j in ipairs(list) do
		local jump = Jump:new()
		jump.current = len - i + 1 == curpos
		-- jump.pos is the position in the real jumplist
		jump.pos = len + 1 - i
		-- position relative to the current jump position
		jump.relpos = len == _curpos and -jump.pos or curpos - jump.pos
		jump.bufnr = j.bufnr
		jump.lnum = j.lnum
		jump.col = j.col
		-- nvim_buf_get_name() fails if buffer does not exist
		if vim.fn.bufexists(j.bufnr) == 1 then
			jump.bufpath = vim.api.nvim_buf_get_name(jump.bufnr)
			-- calculate max lnum per file in order to load files for efficiently
			if not max_lnums[jump.bufpath] or jump.lnum > max_lnums[jump.bufpath] then
				max_lnums[jump.bufpath] = jump.lnum + vim.o.lines
			end
			table.insert(_jumps, jump)
		end
	end

	local jumps = {}
	for _, jump in pairs(_jumps) do
		local lines, err = self.filestore:store(jump.bufpath, max_lnums[jump.bufpath])
		if lines then
			jump.line, jump.err = self.filestore:getline(jump.bufpath, jump.lnum)
		else
			jump.err = err
		end
		if self:_filter(jump, self.context) or curpos == jump.pos then
			table.insert(jumps, jump)
		end
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
	if jump.err then
		return false
	end
	if self.config.jumps.filter_empty_lines and jump.line and vim.trim(jump.line) == "" then
		return false
	end
	if self.filter_func and not self.filter_func(jump, context) then
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

--- Get metadata table
---@param jumps Jumplist
---@return table
local function _get_meta(jumps)
	local meta = {
		jumps_count = #jumps,
		current_jump_line = 1,
		max_basename = 0,
		max_lnum = 0,
		max_col = 0,
		max_relpos = 0,
		-- Maps each path to its shortest unique suffix
		suffixes = {},
		max_suffix = 0,
	}

	local paths = {}
	for i, jump in ipairs(jumps) do
		table.insert(paths, jump.bufpath)
		if jump.current then
			meta.current_jump_line = i
		end
		if not meta.max_lnum or jump.lnum > meta.max_lnum then
			meta.max_lnum = jump.lnum
		end
		if not meta.max_col or jump.col > meta.max_col then
			meta.max_col = jump.col
		end
		local rel = math.abs(jump.relpos)
		if not meta.max_relpos or rel > meta.max_relpos then
			meta.max_relpos = rel
		end
		local basename = vim.fn.strchars(vim.fs.basename(jump.bufpath))
		if not meta.max_basename or basename > meta.max_basename then
			meta.max_basename = basename
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

--- Render the jump list in the given buffer
---@return table Table mapping each line to the jump displayed on it
function Jumplist:_render()
	vim.fn.setbufvar(self.bufnr, "&modifiable", 1)
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
	vim.api.nvim_buf_clear_namespace(self.bufnr, self.nsid, 1, -1)
	local preview_aug = vim.api.nvim_create_augroup("VesselPreview", { clear = true })

	if #self.jumps == 0 then
		vim.fn.setbufline(self.bufnr, 1, self.config.jumps.not_found)
		vim.fn.setbufvar(self.bufnr, "&modifiable", 0)

		self:_setup_mappings({})
		self.window:fit_content()
		self.window:_set_buffer_data({})

		vim.cmd("doau User VesselJumplistChanged")

		if self.window.preview.bufnr ~= -1 then
			self.window.preview:clear()
		end

		return {}
	end

	local map = {}
	local formatter = self.config.jumps.formatters.jump
	local meta = _get_meta(self.jumps)

	local i = 0
	for _, jump in ipairs(self.jumps) do
		i = i + 1
		meta.current_line = i
		local ok, line, matches = pcall(formatter, jump, meta, self.context, self.config)
		if not ok or not line then
			local msg
			if not line then
				msg = string.format("line %s: string expected, got nil", i)
			else
				msg = string.gsub(tostring(line), "^.*:%s+", "")
			end
			self.window:_close_window()
			logger.err("formatter error: %s", msg)
			return {}
		end
		map[i] = jump
		vim.fn.setbufline(self.bufnr, i, line)
		if matches then
			util.set_matches(matches, i, self.bufnr, self.nsid)
		end
	end

	vim.fn.setbufvar(self.bufnr, "&modifiable", 0)

	self:_setup_mappings(map)
	self.window:fit_content()
	util.cursor(meta.current_jump_line)
	self.window:_set_buffer_data(map)
	vim.cmd("doau User VesselJumplistChanged")

	if self.window.preview.bufnr ~= -1 then
		-- Show the file under cursor content in the preview popup
		vim.api.nvim_create_autocmd("CursorMoved", {
			desc = "Write to the preview window on every movement",
			group = preview_aug,
			buffer = self.bufnr,
			callback = function()
				local jump = map[vim.fn.line(".")]
				if jump then
					self.window.preview:show(self.filestore, jump.bufpath, jump.lnum)
				end
			end,
		})
	end

	return map
end

return Jumplist
