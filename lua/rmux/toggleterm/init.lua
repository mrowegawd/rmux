local Config = require("rmux.config")
local has_toggleterm, _ = pcall(require, "toggleterm")

if not has_toggleterm then
	error("This extension requires toggleterm.nvim (https://github.com/akinsho/toggleterm.nvim)")
end

local toggleterm = require("toggleterm")
local ToggletermUtil = require("rmux.toggleterm.util")
local M = {}

function M.send_line(send_pane)
	if send_pane == "" then
		send_pane = 1
		ToggletermUtil.open_toggleterm(send_pane, "horizontal")
		Config.settings.sendID = send_pane
	end

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

function M.send_runfile(langs_opts)
	local term, _ = ToggletermUtil.get_terminals()
	if term and #term == 0 then
		ToggletermUtil.open_toggleterm(1, "horizontal")
		Config.settings.sendID = 1
	end

	if type(langs_opts) == "table" then
		toggleterm.exec(langs_opts.command, tonumber(Config.settings.sendID))
	end
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

return M
