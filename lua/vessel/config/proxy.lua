---@module "proxy"

local logger = require("vessel.logger")

local M = {}

--- Proxy to validate options as soon as they are set
---@param node table Child proxy object
---@param wrapped table Proxied object
---@param validate_func function? Validation function
---@return table Proxy object
local function ConfigProxy(path, node, wrapped, validate_func)
	local proxy = {}
	local meta = {}
	meta.__proxy = true
	meta.__index = function(_, key)
		if not node[key] then
			local fullpath = path ~= "" and path .. "." .. key or key
			logger.err("option validation error: %s: unknown option", fullpath)
			return nil
		end
		local metatable = getmetatable(node[key])
		if metatable and metatable.__proxy then
			-- delegate to the child proxy node
			return node[key]
		else
			return wrapped[key]
		end
	end
	meta.__newindex = function (_, key, val)
		if not node[key] then
			local fullpath = path ~= "" and path .. "." .. key or key
			logger.err("option validation error: %s: unknown option", fullpath)
			return
		end
		-- Build nested table structure just to validate this single option
		local scaffold = {}
		local last = scaffold
		for _, path in pairs(vim.split(path, "\\.", { trimempty = true })) do
			last[path] = {}
			last = last[path]
		end
		last[key] = val
		if not validate_func or (validate_func and validate_func(scaffold)) then
			wrapped[key] = val
		end
	end
	setmetatable(proxy, meta)
	return proxy
end

--- Disallow setting unknown fields and validate on assignment
---@param t table Proxied object
---@param validate_func function? Validation function
---@return table Proxy object
function M.new(t, validate_func)
	local function _make_proxy(path, tree)
		local node = {}
		for key, val in pairs(tree) do
			if type(val) == "table" and not vim.islist(val) then
				local new_path = path == "" and key or path .. "." .. key
				node[key] = _make_proxy(new_path, val)
			else
				node[key] = val
			end
		end
		return ConfigProxy(path, node, tree, validate_func)
	end
	return _make_proxy("", t)
end

return M
