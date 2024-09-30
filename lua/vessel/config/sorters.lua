---@modul "sorters"

local M = {}
M.marks = {}

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
