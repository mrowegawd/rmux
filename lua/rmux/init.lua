local Call = require("rmux.call")
local Config = require("rmux.config")
local Util = require("rmux.utils")

local M = {}

local error_message

local function err_loadMsg()
	if #Config.settings.tasks == nil then
		Util.error("table 'tasks' is empty")
		return false
	end

	if error_message ~= nil then
		Util.error(error_message)

		return false
	end

	return true
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
			Call.command(Config.settings.provider_cmd.RUN_FILE)
		end
	end,
	--  ────────────────────────────────────────────────────────────
	["RmuxSendline"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.provider_cmd.RUN_SEND, true)
		end
	end,
	["RmuxSendlineV"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.provider_cmd.RUN_VSEND, true)
		end
	end,
	["RmuxSelectTargetPane"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.provider_cmd.RUN_TARGET_PANE)
		end
	end,
	["RmuxGrepErr"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.provider_cmd.RUN_GRAB_ERR)
		end
	end,
	["RmuxGrepBuf"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.provider_cmd.RUN_GRAB_BUF)
		end
	end,
	--  ────────────────────────────────────────────────────────────
	["RmuxSendInterrupt"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.provider_cmd.RUN_INTERRUPT)
		end
	end,
	["RmuxSendInterruptAll"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.provider_cmd.RUN_INTERRUPT_ALL)
		end
	end,
	["RmuxKillAllPanes"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.provider_cmd.RUN_KILL_ALL_PANES)
		end
	end,
	--  ────────────────────────────────────────────────────────────
	["RmuxSHOWConfig"] = function()
		Call.command(Config.settings.provider_cmd.RUN_SHOW_CONFIG)
	end,
	["RmuxEDITConfig"] = function()
		Call.command(Config.settings.provider_cmd.RUN_EDIT_CONFIG)
	end,
	["RmuxREDITConfig"] = function()
		Call.command(Config.settings.provider_cmd.RUN_REDIT_CONFIG)
	end,
}

for idx_cmd, cmd in pairs(cmds) do
	vim.api.nvim_create_user_command(idx_cmd, function()
		cmd()
	end, {})
end

return M
