local Config = require("rmux.config")
local Call = require("rmux.call")
local Util = require("rmux.utils")

local M = {}

local error_message

local function err_loadMsg()
	if #Config.settings.langs == nil then
		Util.error({ msg = "table 'langs' is empty" })
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

--  ╭──────────────────────────────────────────────────────────╮
--  │                      COMMANDS INIT                       │
--  ╰──────────────────────────────────────────────────────────╯

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
	-- ["RmuxTargetPane"] = function()
	-- 	if err_loadMsg() then
	-- 		Call.command({}, "change_target_pane")
	-- 	end
	-- end,
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
