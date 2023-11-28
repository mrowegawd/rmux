local has_tt, _ = pcall(require, "tt")
if not has_tt then
	error("This extension requires tt.nvim (https://github.com/distek/tt.nvim)")
end

local Config = require("rmux.config")
local Util = require("rmux.utils")

local M = {}

local tt = require("tt.terminal")
local ttermlist = tt.TermList
-- local ttermlistIdx = tt.TermListIdx

local function __send(first_terminal_chan, text)
	vim.api.nvim_chan_send(first_terminal_chan, text .. "\r")
end

local function __send_visual_or_nah(num_pane, selection_type)
	local lines = {}
	-- Beginning of the selection: line number, column number
	local start_line, start_col
	if selection_type == "single_line" then
		---@diagnostic disable-next-line: deprecated
		start_line, start_col = unpack(vim.api.nvim_win_get_cursor(0))
		table.insert(lines, vim.fn.getline(start_line))
	elseif selection_type == "visual_lines" then
		local res = Util.get_line_selection("visual")
		---@diagnostic disable-next-line: deprecated
		start_line, start_col = unpack(res.start_pos)
		lines = res.selected_lines
	elseif selection_type == "visual_selection" then
		local res = Util.get_line_selection("visual")
		---@diagnostic disable-next-line: deprecated
		start_line, start_col = unpack(res.start_pos)
		lines = Util.get_visual_selection(res)
	end

	if not lines or not next(lines) then
		return
	end

	local trim_spaces = false

	for _, line in ipairs(lines) do
		local l = trim_spaces and line:gsub("^%s+", ""):gsub("%s+$", "") or line
		__send(num_pane, l)
	end

	return start_line, start_col
end

function M.send_line(num_pane)
	num_pane = vim.b[ttermlist[1].buf].terminal_job_id

	local current_window = vim.api.nvim_get_current_win() -- save current window

	local selection_type = "single_line"
	local start_line, start_col = __send_visual_or_nah(num_pane, selection_type)

	vim.api.nvim_set_current_win(current_window)
	vim.api.nvim_win_set_cursor(current_window, { start_line, start_col })
end

function M.send_visual(num_pane)
	num_pane = vim.b[ttermlist[1].buf].terminal_job_id

	local current_window = vim.api.nvim_get_current_win() -- save current window

	local selection_type = "visual_selection"
	local start_line, start_col = __send_visual_or_nah(num_pane, selection_type)

	vim.api.nvim_set_current_win(current_window)
	vim.api.nvim_win_set_cursor(current_window, { start_line, start_col })
end

local function __check_terminal_open(cmd)
	if #ttermlist ~= 0 then
		print("not implemented yet")
	else
		-- print(cmd)
		tt:NewTerminal("hello", cmd)
	end
end

function M.multi_pane(opts, state_cmd)
	local pane_id = 0

	if pane_id then
		table.insert(
			Config.settings.base.tbl_opened_panes,
			{ pane_id = pane_id, open_pane = opts.open_pane, state_cmd = state_cmd, command = opts.command }
		)
	end
end

function M.send_multi()
	for _, panes in pairs(Config.settings.base.tbl_opened_panes) do
		__check_terminal_open(panes.command)
	end
end

return M
