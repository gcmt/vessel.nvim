---@module "vessel"

local M = {}

--- Set/Unset a mark on the current line
---@param global boolean Whether the mark should be global or not
---@param opts table?  Config table
---@return boolean If the mark has been successfully set
local function set_mark(global, opts)
	local config = require("vessel.config").get(opts or {})
	local app = require("vessel.core"):new(config)
	local marklist = require("vessel.marklist"):new(app):init()
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
function M.view_marks(opts)
	local config = require("vessel.config").get(opts or {})
	local app = require("vessel.core"):new(config)
	local marklist = require("vessel.marklist"):new(app)
	marklist:open()
end

--- Open the jump list window
---@param opts table? Config overrides
function M.view_jumps(opts, filter_func)
	local config = require("vessel.config").get(opts or {})
	local app = require("vessel.core"):new(config)
	local jumplist = require("vessel.jumplist"):new(app, filter_func)
	jumplist:open()
end

--- Open the jump list window with only entries belonging to the current buffer
---@param opts table? Config overrides
function M.view_local_jumps(opts)
	M.view_jumps(opts or {}, function(jump, context)
		return jump.bufnr == context.bufnr
	end)
end

--- Main setup funtion. Loads user options
--- Any option passed to this function can still be overridden afterwards by
--- passing options to api functions
function M.setup(opts)
	local config = require("vessel.config").load(opts)

	if config.marks.create_commands then
		vim.api.nvim_create_user_command(config.marks.commands.view, function(_)
			M.view_marks({})
		end, { nargs = 0 })
		vim.api.nvim_create_user_command(config.marks.commands.set_local, function(_)
			M.set_local_mark({})
		end, { nargs = 0 })
		vim.api.nvim_create_user_command(config.marks.commands.set_global, function(_)
			M.set_global_mark({})
		end, { nargs = 0 })
	end

	if config.jumps.create_commands then
		vim.api.nvim_create_user_command(config.jumps.commands.view, function(_)
			M.view_jumps({})
		end, { nargs = 0 })
	end
end

vim.keymap.set("n", "<plug>(VesselViewMarks)", function()
	M.view_marks({})
end)

vim.keymap.set("n", "<plug>(VesselSetLocalMark)", function()
	M.set_local_mark({})
end)

vim.keymap.set("n", "<plug>(VesselSetGlobalMark)", function()
	M.set_global_mark({})
end)

vim.keymap.set("n", "<plug>(VesselViewJumps)", function()
	M.view_jumps({})
end)

--- Filter out jumps not belonging to the current buffer
vim.keymap.set("n", "<plug>(VesselViewLocalJumps)", function()
	M.view_local_jumps({})
end)

return M
