---@modul "sorters"

local M = {}
M.marks = {}
M.buffers = {}

--- Sort buffers by path
---@param a Buffer
---@param b Buffer
---@return boolean
function M.buffers.by_path(a, b)
	return vim.fs.dirname(a.path) < vim.fs.dirname(b.path)
end

--- Sort buffers by basename
---@param a Buffer
---@param b Buffer
---@return boolean
function M.buffers.by_basename(a, b)
	return vim.fs.basename(a.path) < vim.fs.basename(b.path)
end

--- Sort marks by line number
---@param a Mark
---@param b Mark
---@return boolean
function M.marks.by_lnum(a, b)
	return a.lnum < b.lnum
end

--- Sort marks alphabetically
---@param a Mark
---@param b Mark
---@return boolean
function M.marks.by_mark(a, b)
	return a.mark < b.mark
end

--- Sort mark groups
---@param a string Path
---@param b string Path
---@return boolean
function M.marks.sort_groups(a, b)
	return a > b
end

return M
