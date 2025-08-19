local termim, _ = pcall(require, "termim")
if not termim then
	error("This extension requires 2kabhishek/termim.nvim (https://github.com/2KAbhishek/termim.nvim)")
end

local M = {}

function M.get_position_window(win)
	win = win or vim.api.nvim_get_current_win()
	return vim.api.nvim_win_get_number(win)
end

function M.get_current_pane_id()
	return vim.api.nvim_get_current_win()
end

function M.check_right_pane_id(win)
	win = win or vim.api.nvim_get_current_win()
	return vim.api.nvim_win_get_number(win)
end

-- idw: id window
function M.get_pane_idx_from_id(win)
	win = win or vim.api.nvim_get_current_win()
	return vim.api.nvim_win_get_number(win)
end

function M.back_to_pane(cur_pane_idx) end

function M.create_new_pane() end

return M
