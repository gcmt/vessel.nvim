---@mudule "util"

local M = {}

-- Jumping modes
M.modes = {
	BUFFER = 1,
	SPLIT = 2,
	VSPLIT = 3,
	TAB = 4,
}

--- Join arguments with the given separator
---@param sep string
---@param ... any
function M.join(sep, ...)
	local ret = ""
	for i = 1, select("#", ...) do
		if i == 1 then
			ret = tostring(select(i, ...))
		else
			ret = ret .. sep .. tostring(select(i, ...))
		end
	end
	return ret
end

--- Create multiple mappings for the same function handler
---@param mode string
---@param lhs table|string
---@param callback function
---@param opts table?
function M.keymap(mode, lhs, callback, opts)
	opts = vim.tbl_extend("force", { nowait = true, buffer = true, }, opts or {})
	if type(lhs) == "string" then
		vim.keymap.set(mode, lhs, function() callback(lhs) end, opts)
	elseif type(lhs) == "table" then
		for _, mapping in pairs(lhs) do
			vim.keymap.set(mode, mapping, function() callback(mapping) end, opts)
		end
	end
end

--- Resize the current window height to fit its content,
--- up to max_height % of the total lines
---@param max_height integer
---@return integer
function M.fit_content(max_height)
	local max = math.floor(vim.o.lines * max_height / 100)
	local size = math.min(vim.fn.line("$"), max)
	vim.cmd("resize " .. size)
	return size
end

--- Move the cursor to the given position (virtual column)
---Note: vim.fn.cursor() takes a byte count
---@param line integer
---@param col integer? Virtual column
function M.vcursor(line, col)
	vim.fn.cursor(line, 1)
	vim.cmd("norm! " .. (col or 1) .. "|")
end

--- Move the cursor to the given position and adjust view accordingly
---@param line integer
---@param col integer?
function M.cursor(line, col)
	-- Push the last line to the bottom in order to not have any empty space
	vim.fn.cursor(vim.fn.line("$"), 1)
	vim.cmd("norm! zb")
	M.vcursor(line, col or 1)
	-- Unless at the very bottom, center the cursor position
	if vim.fn.line(".") < (vim.fn.line("$") - vim.fn.winheight(0) / 2) then
		vim.cmd("norm! zz")
	end
end

--- Set cursorline only for 'timeout' milliseconds
---@param timeout integer Milliseconds
function M.cursorline(timeout)
	if vim.o.cursorline or not timeout then
		return
	end
	vim.o.cursorline = true
	vim.defer_fn(function()
		vim.o.cursorline = false
	end, timeout)
end

--- Strip $HOME or CWD from the given path
---@param path string
---@return string
function M.prettify_path(path, cwd)
	cwd = cwd or vim.fn.getcwd()
	local home = os.getenv("HOME")
	if cwd ~= home then
		local ret, count = string.gsub(path, "^" .. cwd .. "/", "", 1)
		if count > 0 then
			return ret
		end
	end
	if home then
		return select(1, string.gsub(path, "^" .. home, "~", 1))
	end
	return path
end

--- Set highlight matches on the given line
---@param matches table {hlgroup, startpos, endpos}
---@param line integer 1-indexed
---@param bufnr integer
---@param nsid integer
function M.set_matches(matches, line, bufnr, nsid)
	for _, hl in pairs(matches) do
		vim.api.nvim_buf_add_highlight(
			bufnr,
			nsid,
			hl.hlgroup,
			line - 1,
			hl.startpos - 1,
			hl.endpos
		)
	end
end

---Remove trailing slashes from the given path
---@param path string
---@return string
function M.trim_path(path)
	return select(1, string.gsub(path, "/+$", ""))
end

--- For each path find the shortest unique suffix among all paths
---
--- Example:
--- u = unique_suffixes({"a/b/c.vim", "/d/e/c.vim", "/f.vim"})
--- print(vim.inspect(u))
--- {
---   ["/a/b/c.vim"] = "b/c.vim",
---   ["/d/e/c.vim"] = "e/c.vim",
---   ["/f.vim"] = "f.vim",
---  }
---
---@param paths table
---@retrun table
function M.unique_suffixes(paths)
	local function _uniques(base, paths)
		local seen = {} -- to avoid issues with duplicate paths
		local groups = {}
		for _, p in pairs(paths) do
			local basename = vim.fs.basename(p)
			if not groups[basename] then
				groups[basename] = {}
				seen[basename] = {}
			end
			local dirname = vim.fs.dirname(p)
			if not seen[basename][dirname] then
				table.insert(groups[basename], dirname)
				seen[basename][dirname] = true
			end
		end
		local uniques = {}
		for newbase, dirnames in pairs(groups) do
			if #dirnames == 1 then
				local fullpath = vim.fs.joinpath(dirnames[1], newbase, base)
				uniques[M.trim_path(fullpath)] = M.trim_path(vim.fs.joinpath(newbase, base))
			else
				for fullpath, unique in pairs(_uniques(vim.fs.joinpath(newbase, base), dirnames)) do
					uniques[fullpath] = unique
				end
			end
		end
		return uniques
	end

	return _uniques("", paths)
end

--- Replace every %s placeholder in the given string with the respective value
--- and return highlighing information.
---
--- Example:
--- s, hl = format(
---    "%s > %s %s",
---    { "foo", "Normal" }, "bar", { "baz", "LineNr"}
--- )
---
--- print(s)
--- foo > bar baz
---
--- print(vim.inspect(hl))
--- { {
---     startpos = 1
---     endpos = 3,
---     hlgroup = "Normal",
---   }, {
---     startpos = 11
---     endpos = 13,
---     hlgroup = "LineNr",
--- } }
---
---@param fmt string
---@param ... table|string?
---@return string, table?
function M.format(fmt, ...)
	local splits = vim.split(fmt, "%%s", { trimempty = false })
	local repl = { ... }
	if #repl < #splits - 1 then
		local msg = "format(): got %d arguments, expected at least %d"
		error(string.format(msg, #repl, #splits - 1), 2)
		return "", nil
	end

	local ret = ""
	local matches = {}

	for i, part in pairs(splits) do
		ret = ret .. part
		if repl[i] then
			if type(repl[i]) == "table" then
				local start = #ret + 1
				ret = ret .. repl[i][1]
				table.insert(matches, { startpos = start, endpos = #ret, hlgroup = repl[i][2] })
			else
				ret = ret .. repl[i]
			end
		end
	end

	return ret, matches
end

return M
