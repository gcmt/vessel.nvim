if vim.g.loaded_vessel == 1 then
	return
end
vim.g.loaded_vessel = 1

vim.keymap.set("n", "<plug>(VesselViewBuffers)", function()
	require("vessel").view_buffers()
end)

vim.keymap.set("n", "<plug>(VesselPinnedNext)", function()
	local bufnr
	local vessel = require("vessel")
	local pinned = vessel.get_pinned_list()
	if #pinned == 0 then
		require("vessel.logger").info("vessel: empty pinned list")
		return
	end
	if not vim.tbl_contains(pinned, vim.fn.bufnr("%")) then
		bufnr = pinned[1]
	else
		bufnr = vessel.get_pinned_next()
	end
	if bufnr then
		vim.cmd("buffer " .. bufnr)
	end
end)

vim.keymap.set("n", "<plug>(VesselPinnedPrev)", function()
	local bufnr
	local vessel = require("vessel")
	local pinned = vessel.get_pinned_list()
	if #pinned == 0 then
		require("vessel.logger").info("vessel: empty pinned list")
		return
	end
	if not vim.tbl_contains(pinned, vim.fn.bufnr("%")) then
		bufnr = pinned[#pinned]
	else
		bufnr = vessel.get_pinned_prev()
	end
	if bufnr then
		vim.cmd("buffer " .. bufnr)
	end
end)

vim.keymap.set("n", "<plug>(VesselViewMarks)", function()
	require("vessel").view_marks()
end)

vim.keymap.set("n", "<plug>(VesselViewBufferMarks)", function()
	require("vessel").view_buffer_marks()
end)

vim.keymap.set("n", "<plug>(VesselViewLocalMarks)", function()
	require("vessel").view_local_marks()
end)

vim.keymap.set("n", "<plug>(VesselViewGlobalMarks)", function()
	require("vessel").view_global_marks()
end)

vim.keymap.set("n", "<plug>(VesselViewExternalMarks)", function()
	require("vessel").view_external_marks()
end)

vim.keymap.set("n", "<plug>(VesselSetLocalMark)", function()
	require("vessel").set_local_mark()
end)

vim.keymap.set("n", "<plug>(VesselSetGlobalMark)", function()
	require("vessel").set_global_mark()
end)

vim.keymap.set("n", "<plug>(VesselViewJumps)", function()
	require("vessel").view_jumps()
end)

vim.keymap.set("n", "<plug>(VesselViewLocalJumps)", function()
	require("vessel").view_local_jumps()
end)

vim.keymap.set("n", "<plug>(VesselViewExternalJumps)", function()
	require("vessel").view_external_jumps()
end)
