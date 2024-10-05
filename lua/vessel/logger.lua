---@module "logger"

local M = {}

M.log_level = vim.log.levels.INFO
M.prefixes = {
	err = "vessel: ",
	warn = "vessel: ",
}

--- Set notification prefixes
---@param prefixes table
function M.set_prefixes(prefixes)
	M.prefixes = vim.tbl_extend("force", M.prefixes, prefixes)
end

--- Return prefixe for the given log level
---@param level string
---@return string
local function _get_prefix(level)
	return M.prefixes[level] or M.prefixes.all or ""
end

function M.err(fmt, ...)
	if M.log_level <= vim.log.levels.ERROR then
		local prefix = _get_prefix("err")
		vim.notify_once(prefix .. string.format(fmt, ...), vim.log.levels.ERROR)
	end
end

function M.warn(fmt, ...)
	if M.log_level <= vim.log.levels.WARN then
		local prefix = _get_prefix("warn")
		vim.notify_once(prefix .. string.format(fmt, ...), vim.log.levels.WARN)
	end
end

function M.info(fmt, ...)
	if M.log_level <= vim.log.levels.INFO then
		local prefix = _get_prefix("info")
		vim.notify_once(prefix .. string.format(fmt, ...), vim.log.levels.INFO)
	end
end

function M.debug(fmt, ...)
	if M.log_level <= vim.log.levels.DEBUG then
		local prefix = _get_prefix("debug")
		vim.notify_once(prefix .. string.format(fmt, ...), vim.log.levels.DEBUG)
	end
end

return M
