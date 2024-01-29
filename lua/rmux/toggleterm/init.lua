local has_toggleterm, _ = pcall(require, "toggleterm")
if not has_toggleterm then
	error("This extension requires toggleterm.nvim (https://github.com/akinsho/toggleterm.nvim)")
end

local Config = require("rmux.config")
local Constant = require("rmux.constant")
local Util = require("rmux.utils")
local Ui = require("rmux.ui")

local toggleterm = require("toggleterm")
local ToggletermUtil = require("rmux.toggleterm.util")
local Fzf = require("rmux.fzf")

local M = {}

local current_win_id, current_cur_id

local function __respawn_term()
	local term, _ = ToggletermUtil.get_terminals()
	if term and #term == 0 then
		local term_new_opts = ToggletermUtil.open_toggleterm(1, "horizontal")
		Constant.set_sendID(term_new_opts.id)
	end
end

function M.send_line()
	__respawn_term()
	toggleterm.send_lines_to_terminal("single_line", true, { nargs = "?" })
end

function M.send_visual(send_pane)
	if send_pane == "" then
		send_pane = 1
		ToggletermUtil.open_toggleterm(send_pane, "horizontal")
		Config.settings.sendID = send_pane
	end

	toggleterm.send_lines_to_terminal("visual_selection", true, { range = true, nargs = "?" })
end

function M.send_runfile(opts)
	local cmd_string = vim.split(opts.command, " ")
	if opts.include_cwd then
		local cwd = vim.fn.expand("%:p:h")
		local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
		cmd_string = vim.split(opts.command .. " " .. cwd .. "/" .. fname, " ")
	end
	Ui.run_cmd_async(cmd_string)

	local pane_id = tostring(Constant.get_sendID())
	local pane_num = ToggletermUtil.get_pane_num(Constant.get_sendID())
	local open_pane

	Constant.set_insert_tbl_opened_panes(pane_id, pane_num, open_pane, state_cmd, opts.command, opts.regex)
end

function M.send_interrupt()
	local term, _ = ToggletermUtil.get_terminals()
	if term and #term == 0 then
		return
	end

	if tonumber(Config.settings.sendID) == 0 then
		Config.settings.sendID = 1
	end

	toggleterm.exec("<c-c>", tonumber(Config.settings.sendID))
end

local status_pane_repl = false

function M.openREPL(opts, state_cmd)
	__respawn_term()

	local tbl_opened_panes = Constant.get_tbl_opened_panes()
	local term_ops = Constant.find_state_cmd_on_tbl_opened_panes(state_cmd)

	if not status_pane_repl then
		if Util.tablelength(tbl_opened_panes) == 0 then
			local pane_id = tostring(Constant.get_sendID())
			local pane_num = tostring(Constant.get_sendID())
			local open_pane
			Constant.set_insert_tbl_opened_panes(pane_id, pane_num, open_pane, state_cmd, opts.command, opts.regex)
		else
			status_pane_repl = true
			local cmd_string = opts.command

			-- Check jika state_cmd (openREPL) sudah ada di tbl_opened_panes
			if term_ops ~= nil then
				toggleterm.exec(cmd_string, tonumber(term_ops.pane_id))
			else
				local pane_id = tostring(#tbl_opened_panes + 1)
				local pane_num = tostring(#tbl_opened_panes + 1)
				local open_pane
				Constant.set_insert_tbl_opened_panes(pane_id, pane_num, open_pane, state_cmd, opts.command, opts.regex)
				ToggletermUtil.close_toggleterm()
				toggleterm.exec(cmd_string, tonumber(pane_id))
			end
		end
	else
		for _, value in pairs(ToggletermUtil.get_term_all()) do
			if tonumber(term_ops.pane_id) == value.id then
				if value._state == "h" then
					ToggletermUtil.close_toggleterm()
					vim.cmd("ToggleTerm " .. term_ops.pane_id)
				end
			end
		end
	end
end

function M.open_multi_panes(layouts, state_cmd)
	current_win_id = ToggletermUtil.get_current_win_id()
	current_cur_id = vim.api.nvim_win_get_cursor(0)

	for idx, layout in pairs(layouts) do
		if layout.open_pane ~= nil and #layout.open_pane > 0 then
			local layouts_idx = layouts[idx]
			-- `pane_id` is the command for create, open dan get the id of pane nya langsung
			local pane_id = tostring(idx)
			local pane_num = tostring(idx)

			Constant.set_insert_tbl_opened_panes(
				pane_id,
				pane_num,
				layouts_idx.open_pane,
				state_cmd,
				layouts_idx.command,
				layouts_idx.regex
			)
		else
			Util.warn({ msg = "Why did this happen?\n- There is no file .rmuxrc.json", setnotif = true })
		end
	end

	M.send_multi(state_cmd)
	M.back_to_win_one()
end

function M.back_to_win_one()
	if current_win_id and vim.api.nvim_win_is_valid(current_win_id) then
		vim.api.nvim_set_current_win(current_win_id)
		vim.api.nvim_win_set_cursor(current_win_id, { current_cur_id[1], current_cur_id[2] })
	end
end
function M.send_multi(state_cmd)
	for _, pane in pairs(Constant.get_tbl_opened_panes()) do
		if pane.state_cmd == state_cmd then
			-- toggleterm.exec(pane.command, tonumber(pane.pane_id))
			pane.command = string.gsub(pane.command, "'", "")
			toggleterm.exec(pane.command, tonumber(pane.pane_id))
		end
	end

	-- if #Constant.get_sendID() == "" then
	-- 	Constant.set_sendID(MuxUtil.get_pane_id(MuxUtil.get_total_active_panes()))
	-- end
end

function M.grep_string_pane()
	if Constant.get_sendID() == "" then
		Util.warn({
			msg = "pane or buffer is, are not active, abort it",
			setnotif = true,
		})
		return
	end

	local target_pane_num = ToggletermUtil.get_pane_num(Config.settings.sendID)
	local target_pane_id = Config.settings.sendID

	if target_pane_num and vim.api.nvim_win_is_valid(target_pane_id) then
		local pane_target
		for _, panes in pairs(Constant.get_tbl_opened_panes()) do
			if panes.pane_id == tostring(target_pane_id) then
				pane_target = panes
			end
		end

		if pane_target then
			vim.schedule(function()
				local grep_output = ToggletermUtil.pane_capture(target_pane_num, pane_target.regex)

				if #grep_output > 0 then
					Fzf.grep_err(grep_output, ToggletermUtil.get_pane_num(pane_target.pane_id))
				end
			end)
		end
	end
end

return M
