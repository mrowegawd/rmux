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

local function check_filerc(file_rc)
	local json_tbl = Util.read_json_file(file_rc)
	if
		json_tbl and json_tbl["tasks"] == nil
		or json_tbl and json_tbl["repl"] == nil
		or json_tbl and json_tbl["name"] == nil
	then
		error_message = {
			msg = "file config " .. Config.settings.base.file_rc .. " not recognize some property's, check README",
			setnotif = true,
		}
	end

	return json_tbl
end

local function load_filrc()
	local json_data
	local file_rc = Config.settings.base.fullpath .. "/" .. Config.settings.base.file_rc
	if Util.exists(file_rc) then
		json_data = check_filerc(file_rc)
	else
		local ft = vim.bo.filetype
		local build_str_req = "rmux.fts." .. ft

		if pcall(require, build_str_req) then
			json_data = require(build_str_req)
		end
	end
	if json_data ~= nil then
		Config.settings.langs = json_data
	else
		Config.settings.langs = require("rmux.fts.base")
	end
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
	["RmuxTargetPane"] = function()
		if err_loadMsg() then
			Call.command({}, "change_target_pane")
		end
	end,
	["RmuxGrepErr"] = function()
		if err_loadMsg() then
			Call.command({}, Config.settings.provider_cmd.RUN_GRAB_ERR)
		end
	end,
	["RmuxRunTaskAll"] = function()
		if err_loadMsg() then
			Call.command({}, Config.settings.provider_cmd.RUN_TASKS_ALL)
		end
	end,
	--  ────────────────────────────────────────────────────────────
	["RmuxREPL"] = function()
		if err_loadMsg() then
			Call.command(Config.settings.langs.repl, Config.settings.provider_cmd.RUN_OPENREPL)
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
		load_filrc()
		cmd()
	end, {})
end

return M
