---@module "helptext"

return {
	{ "edit", "Edit current buffer or expand collapsed directory." },
	{ "tab", "Edit current buffer in a new tab." },
	{ "split", "Edit current buffer in a new split." },
	{ "vsplit", "Edit current buffer in a new vertical split." },
	{ "delete", "Delete current buffer with :bdelete." },
	{ "force_delete", "Force delete current buffer with :bdelete!." },
	{ "wipe", "Wipe out current buffer with :bwipeout." },
	{ "force_wipe", "Force wipe out current buffer with :bwipeout!." },
	{ "cycle_sort", "Switch between sorting styles." },
	{ "collapse_directory", "Collapse current directory or buffer parent directory." },
	{ "add_directory", "Add to the buffer list current directory or buffer parent directory." },
	{ "pin_increment", "Increase buffer position in the pinned list." },
	{ "pin_decrement", "Decrease buffer piosition in the pinned list." },
	{ "toggle_pin", "Add or remove current buffer from pinned list." },
	{ "toggle_unlisted", "Toggle visibility of unlisted buffers." },
	{ "toggle_view", "Switch between tree and flat view." },
	{ "toggle_squash", "Toggle directory squashing." },
	{
		"toggle_group",
		"Create or delete group for directory under cursor or buffer parent directory.",
	},
	{ "close", "Close main window." },
}
