---@module "logger"

---@class Logger
---@field _log_level integer
local Logger = {}
Logger.__index = Logger

--- Create new Logger instance
---@param _log_level integer
---@return Logger
function Logger:new(_log_level)
	local logger = {}
	setmetatable(logger, Logger)
	logger._log_level = _log_level
	return logger
end

function Logger:err(fmt, ...)
	if self._log_level <= vim.log.levels.ERROR then
		vim.notify(string.format(fmt, ...), vim.log.levels.ERROR)
	end
end

function Logger:warn(fmt, ...)
	if self._log_level <= vim.log.levels.WARN then
		vim.notify(string.format(fmt, ...), vim.log.levels.WARN)
	end
end

function Logger:info(fmt, ...)
	if self._log_level <= vim.log.levels.INFO then
		vim.notify(string.format(fmt, ...), vim.log.levels.INFO)
	end
end

function Logger:debug(fmt, ...)
	if self._log_level <= vim.log.levels.DEBUG then
		vim.notify(string.format(fmt, ...), vim.log.levels.DEBUG)
	end
end

return Logger
