---@module "proxy"

local logger = require("vessel.logger")
local validate = require("vessel.config.validate")

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
		if node[key] == nil then
			local fullpath = path ~= "" and path .. "." .. key or key
			logger.err("validation error: %s: unknown option", fullpath)
			return nil
		end
		local metatable = getmetatable(node[key])
		if metatable and metatable.__proxy then
			return node[key]
		else
			return wrapped[key]
		end
	end
	meta.__newindex = function(_, key, val)
		local fullpath = path ~= "" and path .. "." .. key or key
		if node[key] == nil then
			logger.err("validation error: %s: unknown option", fullpath)
			return
		end
		local ok, err = pcall(validate.validate_option, fullpath, val)
		if not ok then
			logger.err(string.gsub(tostring(err), "^.-:%d+:%s+", ""))
			return
		end
		wrapped[key] = val
	end
	setmetatable(proxy, meta)
	return proxy
end

--- Disallow setting unknown fields and validate on assignment
---@param t table Proxied object
---@return table Proxy object
function M.new(t)
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
		return ConfigProxy(path, node, tree)
	end
	return _make_proxy("", t)
end

return M
