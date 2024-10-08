---@module "config"

local _opt = require("vessel.config.defaults")
local config_proxy = require("vessel.config.proxy")
local logger = require("vessel.logger")
local validate = require("vessel.config.validate")

local M = {}

--- Validate the given options
---@param opts table?
---@return boolean
local function check_options(opts)
	local ok, err = pcall(validate.validate_partial, opts or {})
	if not ok then
		local msg = string.gsub(tostring(err), "^.-:%d+:%s+", "")
		logger.err("validation error: %s", msg)
		return false
	end
	return true
end

--- Load the config by merging the user-provided config and the default config
---@param opts table?
---@return table
M.load = function(opts)
	if check_options(opts) then
		_opt = vim.tbl_deep_extend("force", _opt, opts or {})
		M.opt = config_proxy.new(_opt)
	end
	return _opt
end

--- Return the current config, overridden by any options passed as argument
---@param opts table?
---@return table
M.get = function(opts)
	if check_options(opts) then
		return vim.tbl_deep_extend("force", _opt, opts or {})
	end
	return _opt
end

--- Proxy object for setting options safely
M.opt = config_proxy.new(_opt)

return M
