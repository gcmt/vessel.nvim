---@module "validate"

local schema = require("vessel.config.schema")
local util = require("vessel.util")

local M = {}

---Validate single option
---@param schema_key string
---@param val any
---@param ignore_unknown boolean?
---@return boolean
function M.validate_option(schema_key, val, ignore_unknown)
	if not ignore_unknown and schema[schema_key] == nil then
		error(string.format("%s: unknown option", schema_key))
	end
	local arg
	local expected = schema[schema_key]
	if type(expected[1]) == "function" then
		arg = { val, unpack(expected) }
	else
		arg = { val, expected }
	end
	local ok, err = pcall(vim.validate, { [schema_key] = arg })
	if not ok then
		error(string.format("%s (%s)", err, val))
	end
	return true
end

---Validate the given config
---@param config table
---@param ignore_unknown boolean? Ignore keys not in the schema
function M.validate_partial(config, ignore_unknown)
	local function _validate_partial(schema_key, config)
		for key, val in pairs(config) do
			local s_key = schema_key == "" and key or util.join(".", schema_key, key)
			M.validate_option(s_key, val, ignore_unknown)
			-- stop if validation on the current value is done by a function
			if type(val) == "table" and type(schema[s_key][1]) ~= "function" then
				_validate_partial(s_key, val)
			end
		end
	end
	_validate_partial("", config)
end

return M
