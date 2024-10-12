---@module "help"

local BufWriter = require("vessel.bufwriter")
local util = require("vessel.util")

local M = {}

--- Render help message in the given buffer
---@param bufnr integer Where to render the help message
---@param header string Help message header
---@param mappings table Table of mappigns
---@param helptext table Help messages for each mapping
---@param close_handler function
function M.render(bufnr, header, mappings, helptext, close_handler)
	local bufwriter = BufWriter:new(bufnr):init()
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

	bufwriter:append(string.format(" %s. Close with 'q'.", header))
	bufwriter:append("")

	for _, help in ipairs(helptext) do
		local mapping
		if type(mappings[help[1]]) == "table" then
			mapping = table.concat(mappings[help[1]], sep)
		else
			mapping = mappings[help[1]]
		end
		local maps_fmt = "%-" .. max_mapping .. "s"
		local maps = string.format(maps_fmt, mapping)
		local line, matches = util.format(" %s  %s", { maps, "Keyword" }, { help[2], "Normal" })
		bufwriter:append(line, matches)
	end

	util.keymap("n", { "q", "<esc>" }, function()
		close_handler()
	end)

	bufwriter:freeze()
end

return M
