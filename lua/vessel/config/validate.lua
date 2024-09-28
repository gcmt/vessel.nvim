---@module "validate"

local util = require("vessel.util")

local M = {}

--- Validate the given config against the given schema.
--- Note: Only keys that also exists in the schema are checked
---@param config table
---@param schema table
function M.validate_partial(config, schema)
	local function validate(schema_key, config, schema)
		for key, val in pairs(config) do
			local s_key = schema_key == "" and key or util.join(".", schema_key, key)
			if schema[s_key] then
				vim.validate({ [s_key] = {val, unpack(schema[s_key])}})
				-- stop if validation on the current value is done by a function
				if type(val) == "table" and type(schema[s_key][1]) ~= "function" then
					validate(s_key, val, schema)
				end
			end
		end
	end
	validate("", config, schema)
end

return M
