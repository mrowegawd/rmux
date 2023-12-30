local has_toggleterm, _ = pcall(require, "toggleterm")
if not has_toggleterm then
	error("This extension requires toggleterm.nvim (https://github.com/akinsho/toggleterm.nvim)")
end

local Config = require("rmux.config")
local Constant = require("rmux.constant")
local Util = require("rmux.utils")

local toggleterm = require("toggleterm")
local ToggletermUtil = require("rmux.toggleterm.util")
local M = {}

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

function M.send_runfile(opts, state_cmd)
	-- __respawn_term()

	-- local tbl_opened_panes = Constant.get_tbl_opened_panes()
	-- local term_ops = Constant.find_state_cmd_on_tbl_opened_panes(state_cmd)
	--
	-- if Util.tablelength(tbl_opened_panes) == 0 then
	-- 	local pane_id = tostring(Constant.get_sendID())
	-- 	local pane_num = tostring(Constant.get_sendID())
	-- 	local open_pane
	-- 	Constant.set_insert_tbl_opened_panes(pane_id, pane_num, open_pane, state_cmd, opts.command, opts.regex)
	-- 	M.send_runfile(opts, state_cmd)
	-- else
	-- 	if term_ops ~= nil then
	-- 		local cmd_string
	-- 		if opts.include_cwd then
	-- 			local cwd = vim.fn.expand("%:p:h")
	-- 			local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
	-- 			cmd_string = opts.command .. " " .. cwd .. "/" .. fname
	-- 		else
	-- 			cmd_string = opts.command
	-- 		end
	-- 		-- print(cmd_string)
	-- 		ToggletermUtil.close_toggleterm()
	-- 		toggleterm.exec(cmd_string, tonumber(Constant.get_sendID()))
	-- 	end
	-- end

	local cmd_string = vim.split(opts.command, " ")
	if opts.include_cwd then
		local cwd = vim.fn.expand("%:p:h")
		local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
		cmd_string = vim.split(opts.command .. " " .. cwd .. "/" .. fname, " ")
	end
	Util.run_script_async(cmd_string)
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
	print("not implemented yet")
end

function M.back_to_pane_one()
	print("not implemented yet")
end
function M.send_multi(state_cmd)
	print("not implemented yet")
end

return M
