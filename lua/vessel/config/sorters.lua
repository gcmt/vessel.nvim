---@modul "sorters"

local M = {}
M.marks = {}
M.buffers = {}

--- Sort buffers by path
---@return function, string
function M.buffers.by_path()
	local fn = function(a, b)
		return vim.fs.dirname(a.path) < vim.fs.dirname(b.path)
	end
	return fn, "sorting by path"
end

--- Sort buffers by last used timestamp (unix time)
---@return function, string
function M.buffers.by_lastused()
	local fn = function(a, b)
		return a.lastused > b.lastused
	end
	return fn, "sorting by last used time"
end

--- Sort buffers by number of changes in the buffeer
---@return function, string
function M.buffers.by_changes()
	local fn = function(a, b)
		return a.changedtick > b.changedtick
	end
	return fn, "sorting by number of changes"
end

--- Sort buffers by basename
---@return function, string
function M.buffers.by_basename()
	local fn = function(a, b)
		return vim.fs.basename(a.path) < vim.fs.basename(b.path)
	end
	return fn, "sorting by basename"
end

--- Sort marks by line number
---@return function, string
function M.marks.by_lnum()
	local fn = function(a, b)
		return a.lnum < b.lnum
	end
	return fn, "sorting by line number"
end

--- Sort marks alphabetically
---@return function, string
function M.marks.by_mark()
	local fn = function(a, b)
		return a.mark < b.mark
	end
	return fn, "sorting alphabetically"
end

--- Sort mark groups
---@param a string Path
---@param b string Path
---@return boolean
function M.marks.sort_groups(a, b)
	return a > b
end

return M
