---@modeul "filestore"

---@class FileStore
---@field _store table
local FileStore = {}
FileStore.__index = FileStore

--- Create new FileStore instance
---@return FileStore
function FileStore:new()
	local store = {}
	setmetatable(store, FileStore)
	store._store = {}
	return store
end

--- Read file content up to 'max' lines
---@param path string
---@param max integer?
---@return string[]?, string?
local function _readfile(path, max)
	local f, _ = io.open(path, "r")
	if not f then
		return nil, string.format("%s: no such file", vim.fs.basename(path))
	end
	local count = 1
	local lines = {}
	for line in f:lines() do
		lines[count] = line
		if max and count == max then
			break
		end
		count = count + 1
	end
	f:close()
	return lines, nil
end

--- Store file up to 'max' lines
---@param path string File to retrieve
---@param max integer? Maximum line to get when reading from the filesystem
---@return string[]?, string?
function FileStore:store(path, max)
	max = max or -1
	if self._store[path] and #self._store[path] >= max then
		return self._store[path]
	end
	if vim.fn.bufloaded(path) == 1 then
		self._store[path] = vim.api.nvim_buf_get_lines(vim.fn.bufnr(path), 0, -1, false)
		return self._store[path], nil
	end
	local lines, err = _readfile(path, max)
	if not lines then
		return nil, err
	end
	self._store[path] = lines
	return lines, nil
end

--- Get a file from the store
---@param path string
---@param force boolean? Force reading file from the filesystem
---@return string[]?, string?
function FileStore:getfile(path, force)
	if self._store[path] then
		return self._store[path], nil
	end
	if not force then
		return nil, string.format("%s: no such file", vim.fs.basename(path))
	end
	return self:store(path)
end

--- Get a specific line from the file in store
---@param path string
---@param lnum integer
---@param force boolean? Force reading file from the filesystem
---@return string?, string?
function FileStore:getline(path, lnum, force)
	local lines, err = self:getfile(path, force)
	if not lines then
		return nil, err
	end
	if not lines[lnum] then
		return nil, string.format("%s:%d: no such line", vim.fs.basename(path), lnum)
	end
	return lines[lnum], nil
end

return FileStore
