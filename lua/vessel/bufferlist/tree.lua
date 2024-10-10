---@module "tree"

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
			return Tree:new(vim.fs.joinpath(unpack(head)), tree, buffer)
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
--- NOTE: One for cwd, one for home and one for root directory
---@param buffers Buffer[]
---@return table
function M.make_trees(buffers)
	local cwd = vim.fn.getcwd()
	local home = os.getenv("HOME") or "/home"
	local groups = { Tree:new(cwd), Tree:new(home), Tree:new("/") }
	for _, buffer in ipairs(buffers) do
		if vim.startswith(buffer.path, cwd .. "/") or buffer.path == "" then
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
