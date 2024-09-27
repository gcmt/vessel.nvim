---@module "logger"

---@class Logger
---@field _log_level integer
---@field _prefixes table
local Logger = {}
Logger.__index = Logger

--- Create new Logger instance
---@param log_level integer
---@return Logger
function Logger:new(log_level)
	local logger = {}
	setmetatable(logger, Logger)
	logger._log_level = log_level
	logger._prefixes = {}
	return logger
end

---Set notification prefixes
---@param prefixes table
function Logger:set_prefixes(prefixes)
	self._prefixes = vim.tbl_extend("force", self._prefixes, prefixes)
end

---Return prefixe for the given log level
---@param level string
---@return string
function Logger:_get_prefix(level)
	return self._prefixes[level] or self._prefixes.all or ""
end

function Logger:err(fmt, ...)
	if self._log_level <= vim.log.levels.ERROR then
		local prefix = self:_get_prefix("err")
		vim.notify(prefix .. string.format(fmt, ...), vim.log.levels.ERROR)
	end
end

function Logger:warn(fmt, ...)
	if self._log_level <= vim.log.levels.WARN then
		local prefix = self:_get_prefix("warn")
		vim.notify(prefix .. string.format(fmt, ...), vim.log.levels.WARN)
	end
end

function Logger:info(fmt, ...)
	if self._log_level <= vim.log.levels.INFO then
		local prefix = self:_get_prefix("info")
		vim.notify(prefix .. string.format(fmt, ...), vim.log.levels.INFO)
	end
end

function Logger:debug(fmt, ...)
	if self._log_level <= vim.log.levels.DEBUG then
		local prefix = self:_get_prefix("debug")
		vim.notify(prefix .. string.format(fmt, ...), vim.log.levels.DEBUG)
	end
end

return Logger
