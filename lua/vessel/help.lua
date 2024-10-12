---@module "help"

local util = require("vessel.util")

local M = {}

--- Render help message in the given buffer
---@param bufnr integer
---@param nsid integer
---@param header string Help message header
---@param mappings table Table of mappigns
---@param helptext table Help messages for each mapping
---@param close_handler function
function M.render(bufnr, nsid, header, mappings, helptext, close_handler)
	vim.fn.setbufvar(bufnr, "&modifiable", 1)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
	vim.api.nvim_buf_clear_namespace(bufnr, nsid, 1, -1)
	vim.api.nvim_create_augroup("VesselPreview", { clear = true })

	local sep = ", "

	local max_mapping
	for _, maps in pairs(mappings) do
		local len
		if type(maps) == "table" then
			len = #table.concat(maps, sep)
		else
			len = #maps
		end
		if not max_mapping or len > max_mapping then
			max_mapping = len
		end
	end

	vim.fn.setbufline(bufnr, 1, string.format("%s. Close with 'q'.", header))
	vim.fn.setbufline(bufnr, 2, "")

	local i = 3
	for _, help in ipairs(helptext) do
		local mapping
		if type(mappings[help[1]]) == "table" then
			mapping = table.concat(mappings[help[1]], sep)
		else
			mapping = mappings[help[1]]
		end
		local maps_fmt = "%-" .. max_mapping .. "s"
		local maps = string.format(maps_fmt, mapping)
		local line, matches = util.format("%s  %s", { maps, "Keyword" }, { help[2], "Normal" })
		vim.fn.setbufline(bufnr, i, line)
		util.set_matches(matches or {}, i, bufnr, nsid)
		i = i + 1
	end

	util.keymap("n", { "q", "<esc>" }, function()
		close_handler()
	end)

	vim.fn.setbufvar(bufnr, "&modifiable", 0)
end

return M
