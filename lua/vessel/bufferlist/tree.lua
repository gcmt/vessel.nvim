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

--- Count buffer in the tree
---@return integer
function Tree:count()
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
---@param custom_groups string[]
---@return table
function M.make_trees(buffers, custom_groups)
	local groups = {}
	for _, g in pairs(custom_groups) do
		groups[g] = Tree:new(g)
	end

	local cwd = vim.fn.getcwd()
	local home = os.getenv("HOME") or "/home"

	-- therse groups are always going to be present
	groups[cwd] = Tree:new(cwd)
	groups[home] = Tree:new(home)
	groups["/"] = Tree:new("/")

	-- Sort groups from most specific to less specific. The buffer needs to be
	-- captured by the most specific match
	local prefixes = vim.tbl_keys(groups)
	table.sort(prefixes, function(a, b)
		return a > b
	end)

	for _, buffer in ipairs(buffers) do
		for _, prefix in ipairs(prefixes) do
			if buffer.path == "" then
				groups[cwd]:insert(buffer, string.gsub(buffer.path, cwd, "", 1))
				break
			elseif vim.startswith(buffer.path, prefix .. "/") then
				groups[prefix]:insert(buffer, string.gsub(buffer.path, prefix, "", 1))
				break
			end
		end
	end

	local ret = {}
	for _, prefix in ipairs(prefixes) do
		table.insert(ret, groups[prefix])
	end

	return ret
end

return M
