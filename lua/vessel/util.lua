---@mudule "util"

local M = {}

-- Jumping modes
M.modes = {
	BUFFER = 1,
	SPLIT = 2,
	VSPLIT = 3,
	TAB = 4,
}

--- Find next available buffer
---@param bufnr integer Buffer to replace
---@return integer?
function M.find_repl_buf(bufnr)
	for _, b in pairs(vim.fn.getbufinfo()) do
		if b.bufnr ~= bufnr and b.listed == 1 and vim.fn.getbufvar(b.bufnr, "&buftype") == "" then
			return b.bufnr
		end
	end
end

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
	opts = vim.tbl_extend("force", { nowait = true, buffer = true }, opts or {})
	if type(lhs) == "string" then
		vim.keymap.set(mode, lhs, function()
			callback(lhs)
		end, opts)
	elseif type(lhs) == "table" then
		for _, mapping in pairs(lhs) do
			if mapping ~= "" then
				vim.keymap.set(mode, mapping, function()
					if string.match(string.lower(mapping), "mouse") then
						vim.cmd('exec "norm! \\<leftmouse>"')
					end
					callback(mapping)
				end, opts)
			end
		end
	end
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

--- Plain text replacement at the start of a string
---@param s string Source string
---@param target string The string to replace
---@param repl string Replacement string
--@return string, boolean
function M.replstart(s, target, repl)
	local startpos, endpos = string.find(s, target, 1, true)
	if not startpos or startpos > 1 then
		return s, false
	end
	return string.sub(s, 1, startpos - 1) .. repl .. string.sub(s, endpos + 1), true
end

--- Strip $HOME or CWD from the given path
---@param path string
---@param cwd string?
---@return string
function M.prettify_path(path, cwd)
	cwd = cwd or vim.fn.getcwd()
	local home = os.getenv("HOME")
	if cwd ~= home then
		local ret, ok = M.replstart(path, cwd .. "/", "")
		if ok then
			return ret
		end
	end
	if home then
		local ret, _ = M.replstart(path, home, "~")
		return ret
	end
	return path
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
				ret = ret .. tostring(repl[i][1])
				table.insert(matches, { startpos = start, endpos = #ret, hlgroup = repl[i][2] })
			else
				ret = ret .. repl[i]
			end
		end
	end

	return ret, matches
end

--- Reset window
---@param winid integer
function M.reset_window(winid)
	local wininfo = vim.fn.getwininfo(winid)
	local bufnr = wininfo[1].bufnr
	local winnr = wininfo[1].winnr
	vim.fn.setbufvar(bufnr, "&buftype", "nofile")
	vim.fn.setbufvar(bufnr, "&bufhidden", "delete")
	vim.fn.setbufvar(bufnr, "&buflisted", 0)
	vim.fn.setwinvar(winnr, "&cursorcolumn", 0)
	vim.fn.setwinvar(winnr, "&colorcolumn", 0)
	vim.fn.setwinvar(winnr, "&signcolumn", "no")
	vim.fn.setwinvar(winnr, "&wrap", 0)
	vim.fn.setwinvar(winnr, "&list", 0)
	vim.fn.setwinvar(winnr, "&textwidth", 0)
	vim.fn.setwinvar(winnr, "&undofile", 0)
	vim.fn.setwinvar(winnr, "&backup", 0)
	vim.fn.setwinvar(winnr, "&swapfile", 0)
	vim.fn.setwinvar(winnr, "&spell", 0)
end

return M
