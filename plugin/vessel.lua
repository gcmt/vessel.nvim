if vim.g.loaded_vessel == 1 then
	return
end
vim.g.loaded_vessel = 1

vim.keymap.set("n", "<plug>(VesselViewBuffers)", function()
	require("vessel").view_buffers()
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
