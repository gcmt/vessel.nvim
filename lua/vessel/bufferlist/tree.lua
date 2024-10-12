---@module "tree"

local util = require("vessel.util")

local M = {}

---@class Tree
---@field path string Path up to this node (relative to root node)
---@field buffer Buffer Node is a real buffer
---@field parent Tree?
---@field children Tree[]
local Tree = {}
Tree.__index = Tree

--- Create a new Tree instance
---@param path string
---@param parent Tree?
---@param buffer Buffer?
function Tree:new(path, parent, buffer)
	local tree = {}
	setmetatable(tree, Tree)
	tree.path = path
	tree.buffer = buffer
	tree.parent = parent
	tree.children = {}
	return tree
end

--- Wheter node is a leaf
---@return boolean
function Tree:is_leaf()
	return #self.children == 0
end

--- Insert the buffer @ path in the tree
--- NOTE: Buffers are mostly leaves unless they are directories themselves
---@param buffer Buffer
---@param path string
function Tree:insert(buffer, path)
	---@param tree Tree
	---@param head string[] Path consumed
	---@param tail string[] Path yet to consume
	---@return Tree
	local function _insert(tree, head, tail)
		if #tail == 0 then
			tree.buffer = buffer
			return tree
		end
		table.insert(head, table.remove(tail, 1))
		local head_path = vim.fs.joinpath(unpack(head))
		for _, node in pairs(tree.children) do
			if head_path == node.path then
				_insert(node, head, tail)
				goto continue
			end
		end
		table.insert(tree.children, _insert(Tree:new(head_path, tree), head, tail))
		::continue::
		return tree
	end

	if path == "" then
		path = "[no name]"
	end

	return _insert(self, {}, vim.split(path, "/", { trimempty = true }))
end

--- Find first descendant directory that has multiple children
--- "Eat up" each node that has only one directory child
---@return Tree?
function Tree:fast_forward()
	---@param tree Tree
	local function _next(tree)
		if #tree.children == 1 and not tree.children[1].buffer then
			return _next(tree.children[1])
		elseif #tree.children > 0 then
			return tree
		end
		return nil
	end
	local node = _next(self)
	if node == self then
		return nil
	end
	return node
end

--- Count buffers in the tree
---@return integer
function Tree:count_buffers()
	---@param tree Tree
	---@param acc integer Accumulator
	local function _count(tree, acc)
		if tree.buffer then
			acc = acc + 1
		end
		for _, child in pairs(tree.children) do
			acc = _count(child, acc)
		end
		return acc
	end
	return _count(self, 0)
end

--- Pretty print the tree
function Tree:_pprint()
	---@param tree Tree
	---@param padding string Tree decoration lines
	---@param is_last boolean Node is last child
	local function _print(tree, padding, is_last)
		local curr_padding = ""
		local next_padding = padding

		if not tree.parent then
			print(tree.path)
		else
			curr_padding = padding .. (is_last and "└─ " or "├─ ")
			next_padding = padding .. (is_last and "   " or "│  ")
			print(curr_padding .. vim.fs.basename(tree.path))
		end

		for i, child in ipairs(tree.children) do
			_print(child, next_padding, i == #tree.children)
		end
	end
	_print(self, "", false)
end

--- Return buffers grouped in multiple trees
---@param buffers Buffer[]
---@param groups string[] Order must be preserved
---@return table
function M.make_trees(buffers, groups)
	local _groups = {}
	for _, g in pairs(groups) do
		_groups[g] = Tree:new(g)
	end

	local cwd = vim.fn.getcwd()
	local home = os.getenv("HOME") or "/home"

	-- therse groups are always going to be present
	if not _groups[cwd] then
		_groups[cwd] = Tree:new(cwd)
		table.insert(groups, cwd)
	end
	if not _groups[home] then
		_groups[home] = Tree:new(home)
		table.insert(groups, home)
	end
	if not _groups["/"] then
		_groups["/"] = Tree:new("/")
		table.insert(groups, "/")
	end

	-- Sort groups from most specific to less specific. The buffer needs to be
	-- captured by the most specific match
	local prefixes = vim.tbl_keys(_groups)
	table.sort(prefixes, function(a, b)
		return a > b
	end)

	for _, buffer in ipairs(buffers) do
		if buffer.path == "" then
			_groups[cwd]:insert(buffer, string.gsub(buffer.path, cwd, "", 1))
			goto continue
		end
		for _, prefix in ipairs(prefixes) do
			if vim.startswith(buffer.path, util.trim_path(prefix) .. "/") then
				_groups[prefix]:insert(buffer, string.gsub(buffer.path, prefix, "", 1))
				goto continue
			end
		end
		::continue::
	end

	local ret = {}
	for _, path in ipairs(groups) do
		table.insert(ret, _groups[path])
	end

	return ret
end

return M
