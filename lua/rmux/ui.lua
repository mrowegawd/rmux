local Util = require("rmux.utils")

local M = {}
local buf, win
local filetype = "rmux_output"
local Constant = require("rmux.constant")

function M.create_win()
	vim.api.nvim_command("botright vnew")
	win = vim.api.nvim_get_current_win()
	buf = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_name(0, "result #" .. buf)

	vim.api.nvim_buf_set_option(0, "buftype", "nofile")
	vim.api.nvim_buf_set_option(0, "swapfile", false)
	vim.api.nvim_buf_set_option(0, "filetype", filetype)
	vim.api.nvim_buf_set_option(0, "bufhidden", "wipe")

	vim.api.nvim_command("setlocal nowrap")
	-- vim.api.nvim_command("setlocal cursorline")
	Constant.set_sendID(win)
end
local function on_stdout(_, data)
	if data then
		for _, line in ipairs(data) do
			if line ~= "" then
				vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line })
			end
		end
	end
end

function M.run_cmd_async(cmd)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	M.create_win()

	Util.run_jobstart(cmd, on_stdout)

	vim.cmd([[wincmd p]])
end

return M
