---@module "bufwriter"

---@class BufWriter
---@field bufnr integer Buffer number
---@field nsid integer Namespace ID
---@field lnum integer Internally keep track of the last line number
local BufWriter = {}
BufWriter.__index = BufWriter

--- Create new BufWriter instance
---@param bufnr integer
---@return BufWriter
function BufWriter:new(bufnr)
	local bufwriter = {}
	setmetatable(bufwriter, BufWriter)
	bufwriter.nsid = vim.api.nvim_create_namespace("__vessel__")
	bufwriter.bufnr = bufnr
	bufwriter.lnum = 0
	return bufwriter
end

--- Initialize and clear buffer
---@return BufWriter
function BufWriter:init()
	vim.fn.setbufvar(self.bufnr, "&modifiable", 1)
	vim.api.nvim_buf_clear_namespace(self.bufnr, self.nsid, 1, -1)
	self:clear()
	return self
end

--- Delete all lines in the buffer
---@return BufWriter
function BufWriter:clear()
	vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, {})
	self.lnum = 0
	return self
end

--- Make the buffer to non-modifiable
function BufWriter:freeze()
	vim.fn.setbufvar(self.bufnr, "&modifiable", 0)
end

--- Append line to buffer and set highlight matches
---@param line string Line to append
---@param matches table? Highlight matches
---@return BufWriter
function BufWriter:append(line, matches)
	self.lnum = self.lnum + 1
	vim.fn.setbufline(self.bufnr, self.lnum, line)
	if matches then
		self:set_matches(self.lnum, matches)
	end
	return self
end

--- Set highlight matches on the given line
---@param lnum integer Line number
---@param matches table {{hlgroup, startpos, endpos}, ..}
function BufWriter:set_matches(lnum, matches)
	for _, hl in pairs(matches) do
		vim.api.nvim_buf_add_highlight(
			self.bufnr,
			self.nsid,
			hl.hlgroup,
			lnum - 1,
			hl.startpos - 1,
			hl.endpos
		)
	end
end

return BufWriter
