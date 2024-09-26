---@module "context"

---@class Context
---@field bufpath string
---@field bufnr integer
---@field wininfo table
---@field curpos table
local Context = {}
Context.__index = Context

--- Return a new Context instance
--- A Context represent information about a specific window.
--- If a window id is not provided, information about the currently focused
--- window is returned instead.
---
---@param winid integer?
---@return Context
function Context:new(winid)
	local ctx = {}
	setmetatable(ctx, Context)
	local id = winid or vim.api.nvim_get_current_win()
	local wininfo = vim.fn.getwininfo(id)[1]
	ctx.bufpath = vim.api.nvim_buf_get_name(wininfo.bufnr)
	ctx.bufnr = wininfo.bufnr
	ctx.wininfo = wininfo
	ctx.curpos = vim.fn.getcurpos(id)
	return ctx
end

return Context
