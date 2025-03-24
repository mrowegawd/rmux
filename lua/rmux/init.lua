local Call = require("rmux.call")
local Config = require("rmux.config")
local Constant = require("rmux.constant")
local Util = require("rmux.utils")

local M = {}

local error_message

local function err_loadMsg()
	if #Config.settings.tasks == nil then
		Util.error({ msg = "table 'tasks' is empty" })
		return false
	end

	if error_message ~= nil then
		Util.error(error_message)

		return false
	end

	return true
end

local function remove_percent(s)
	return vim.split(s:gsub("%%", ""), " ")[1]
end

local function capitalize_first_letter(str)
	return (str:gsub("^%l", string.upper))
end

function M.status_panes_targeted()
	if #Constant.get_tbl_opened_panes() == 0 then
		return {}
	end

	local selected_panes = Constant.get_selected_pane()
	if selected_panes and #selected_panes > 0 then
		local result = { watch = {}, run_with = capitalize_first_letter(Config.settings.base.run_with) }

		for _, value in ipairs(selected_panes) do
			table.insert(result.watch, remove_percent(value))
		end
		return result
	end
	return {}
end

--  ╭──────────────────────────────────────────────────────────╮
--  │                        BASE SETUP                        │
--  ╰──────────────────────────────────────────────────────────╯

function M.setup(opts)
	Config.update_settings(opts)

	Config.settings.base.fullpath = Util.get_root_path()
	Config.settings.base.path = vim.fs.basename(Config.settings.base.fullpath)
end

local cmds = {
	["RmuxRunFile"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.sendID, Config.settings.provider_cmd.RUN_FILE)
		end
	end,
	--  ────────────────────────────────────────────────────────────
	["RmuxSendline"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.sendID, Config.settings.provider_cmd.RUN_SENDID)
		end
	end,
	["RmuxSendVisualSelection"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.sendID, Config.settings.provider_cmd.RUN_VSENDID)
		end
	end,
	["RmuxSelectTargetPane"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.sendID, Config.settings.provider_cmd.RUN_TARGET_PANE)
		end
	end,
	["RmuxGrepErr"] = function()
		if err_loadMsg() then
			Call.command({}, Config.settings.provider_cmd.RUN_GRAB_ERR)
		end
	end,
	--  ────────────────────────────────────────────────────────────
	["RmuxSendInterrupt"] = function()
		if err_loadMsg() then
			Call.command("interrupt_single", Config.settings.provider_cmd.RUN_INTERRUPT)
		end
	end,
	["RmuxSendInterruptAll"] = function()
		if err_loadMsg() then
			Call.command("interrupt_all", Config.settings.provider_cmd.RUN_INTERRUPT_ALL)
		end
	end,
	["RmuxKillAllPanes"] = function()
		if err_loadMsg() then
			Call.command("kill_all_panes", Config.settings.provider_cmd.RUN_KILL_ALL_PANES)
		end
	end,
	--  ────────────────────────────────────────────────────────────
	["RmuxSHOWConfig"] = function()
		print(vim.inspect(Config.settings))
		-- print(vim.inspect(Config.settings.base.tbl_opened_panes))
		-- print(vim.inspect(Config.settings.sendID))
	end,
	["RmuxEDITConfig"] = function()
		Call.command(true, "edit_or_reload_config")
	end,
	["RmuxREDITConfig"] = function()
		Call.command(false, "redit_config")
	end,
}

for idx_cmd, cmd in pairs(cmds) do
	vim.api.nvim_create_user_command(idx_cmd, function()
		cmd()
	end, {})
end

return M
