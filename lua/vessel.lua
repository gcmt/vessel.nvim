---@module "vessel"

local M = {}

local function lazy_opt()
	local t = {}
	setmetatable(t, {
		__index = function(_, key)
			return require("vessel.config").opt[key]
		end,
		__newindex = function(_, key, val)
			require("vessel.config").opt[key] = val
		end,
	})
	return t
end

M.opt = lazy_opt()

--- Open the buffer list window
---@param opts table? Config overrides
---@param filter_func function?
function M.view_buffers(opts, filter_func)
	local config = require("vessel.config").get(opts)
	local bufferlist = require("vessel.bufferlist"):new(config, filter_func)
	bufferlist:open()
end

--- Get pinned buffers list
---@param opts table? Config overrides
---@return table
function M.get_pinned_list(opts)
	local config = require("vessel.config").get(opts)
	local bufferlist = require("vessel.bufferlist"):new(config)
	return bufferlist:get_pinned_list()
end

--- Get the next buffer number in the pinned list
---@param bufnr integer? Return the buffer after the given one
---@param opts table? Config overrides
---@return integer?
function M.get_pinned_next(bufnr, opts)
	local config = require("vessel.config").get(opts)
	local bufferlist = require("vessel.bufferlist"):new(config)
	return bufferlist:get_pinned_next(bufnr or vim.fn.bufnr("%"))
end

--- Get the previous buffer number in the pinned list
---@param bufnr integer? Return the buffer before the given one
---@param opts table? Config overrides
---@return integer?
function M.get_pinned_prev(bufnr, opts)
	local config = require("vessel.config").get(opts)
	local bufferlist = require("vessel.bufferlist"):new(config)
	return bufferlist:get_pinned_prev(bufnr or vim.fn.bufnr("%"))
end

--- Set/Unset a mark on the current line
---@param global boolean Whether the mark should be global or not
---@param opts table?  Config table
---@return boolean If the mark has been successfully set
local function set_mark(global, opts)
	local config = require("vessel.config").get(opts)
	local marklist = require("vessel.marklist"):new(config):init()
	return marklist:set_mark(global)
end

--- Set mark local to the current buffer
---@param opts table? Config overrides
---@return boolean If the mark has been successfully set
function M.set_local_mark(opts)
	return set_mark(false, opts)
end

--- Set global mark
---@param opts table? Config overrides
---@return boolean If the mark has been successfully set
function M.set_global_mark(opts)
	return set_mark(true, opts)
end

--- Open the mark list window
---@param opts table? Config overrides
---@param filter_func function?
function M.view_marks(opts, filter_func)
	local config = require("vessel.config").get(opts)
	local marklist = require("vessel.marklist"):new(config, filter_func)
	marklist:open()
end

--- Open the mark list window with only entries belonging to the current buffer
---@param opts table? Config overrides
function M.view_buffer_marks(opts)
	M.view_marks(opts, function(mark, context)
		return mark.file == context.bufpath
	end)
end

--- Open the mark list window with only local (lowercase) marks
---@param opts table? Config overrides
function M.view_local_marks(opts)
	M.view_marks(opts, function(mark, context)
		return string.match(mark.mark, "%l")
	end)
end

--- Open the mark list window with only global (uppercase) marks
---@param opts table? Config overrides
function M.view_global_marks(opts)
	M.view_marks(opts, function(mark, context)
		return string.match(mark.mark, "%u")
	end)
end

--- Open the mark list window with only external marks
---@param opts table? Config overrides
function M.view_external_marks(opts)
	M.view_marks(opts, function(mark, context)
		return mark.file ~= context.bufpath
	end)
end

--- Open the jump list window
---@param opts table? Config overrides
---@param filter_func function?
function M.view_jumps(opts, filter_func)
	local config = require("vessel.config").get(opts)
	local jumplist = require("vessel.jumplist"):new(config, filter_func)
	jumplist:open()
end

--- Open the jump list window with only entries belonging to the current buffer
---@param opts table? Config overrides
function M.view_local_jumps(opts)
	M.view_jumps(opts, function(jump, context)
		return jump.bufnr == context.bufnr
	end)
end

--- Open the jump list window with only entries outside the current buffer
---@param opts table? Config overrides
function M.view_external_jumps(opts)
	M.view_jumps(opts, function(jump, context)
		return jump.bufnr ~= context.bufnr
	end)
end

--- Main setup funtion. Loads user options
--- Any option passed to this function can still be overridden afterwards by
--- passing options to api functions
function M.setup(opts)
	local config = require("vessel.config").load(opts)
	if config.create_commands then
		vim.api.nvim_create_user_command(config.commands.view_marks, function(_)
			M.view_marks()
		end, { nargs = 0 })
		vim.api.nvim_create_user_command(config.commands.view_jumps, function(_)
			M.view_jumps()
		end, { nargs = 0 })
		vim.api.nvim_create_user_command(config.commands.view_buffers, function(_)
			M.view_buffers()
		end, { nargs = 0 })
	end
end

return M
