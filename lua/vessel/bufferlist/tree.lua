---@module "tree"

local M = {}

---@class Tree
---@field path string Path up to this node (relative to root node)
---@field is_root boolean Node is the root node
---@field children Tree[]
local Tree = {}
Tree.__index = Tree

--- Create a new Tree instance
---@param path string
---@param is_root boolean?
function Tree:new(path, is_root)
	local tree = {}
	setmetatable(tree, Tree)
	tree.is_root = is_root
	tree.path = path
	tree.children = {}
	return tree
end

--- Insert the buffer @ path in the tree
--- NOTE: Only Buffers can be tree leaves
---@param buffer Buffer
---@param path string
function Tree:insert(buffer, path)
	---@param tree Tree
	---@param head string[] Path consumed
	---@param tail string[] Path yet to consume
	---@return Tree|Buffer
	local function _insert(tree, head, tail)
		if #tail == 0 then
			return buffer
		end
		table.insert(head, table.remove(tail, 1))
		local head_path = vim.fs.joinpath(unpack(head))
		for _, node in pairs(tree.children) do
			if head_path == node.path then
				_insert(node, head, tail)
				goto continue
			end
		end
		table.insert(tree.children, _insert(Tree:new(head_path), head, tail))
		::continue::
		return tree
	end
	return _insert(self, {}, vim.split(path, "/", { trimempty = true }))
end

--- Pretty print the tree
function Tree:_pprint()
	---@param tree Tree|Buffer
	---@param padding string Tree decoration lines
	---@param is_last boolean Node is last child
	local function _print(tree, padding, is_last)
		local curr_padding = ""
		local next_padding = padding

		local path, children
		if not tree.children then
			path = vim.fs.basename(tree.path)
			children = {}
		else
			path = tree.path
			children = tree.children
		end

		if not tree.is_root then
			curr_padding = padding .. (is_last and "└─ " or "├─ ")
			next_padding = padding .. (is_last and "   " or "│  ")
			print(curr_padding .. vim.fs.basename(path))
		elseif children then
			print(path)
		end

		for i, child in ipairs(tree.children or {}) do
			_print(child, next_padding, i == #children)
		end
	end

	if #self.children > 0 then
		_print(self, "", false)
	end
end

--- Return buffers grouped in multiple trees
--- NOTE: One for cwd, one for home and one for root directory
---@param buffers Buffer[]
---@return table
function M.make_trees(buffers)
	local cwd = vim.fn.getcwd()
	local home = os.getenv("HOME") or "/home"
	local groups = {
		Tree:new(cwd, true),
		Tree:new(home, true),
		Tree:new("/", true),
	}
	table.sort(buffers, function(a, b)
		-- files first
		return vim.fs.dirname(a.path) < vim.fs.dirname(b.path)
	end)
	for _, buffer in ipairs(buffers) do
		if vim.startswith(buffer.path, cwd .. "/") then
			groups[1]:insert(buffer, string.gsub(buffer.path, cwd, "", 1))
		elseif vim.startswith(buffer.path, home .. "/") then
			groups[2]:insert(buffer, string.gsub(buffer.path, home, "", 1))
		elseif vim.startswith(buffer.path, "/") then
			groups[3]:insert(buffer, buffer.path)
		end
	end
	return groups
end

return M
