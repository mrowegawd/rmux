local Config = require("rmux.config")
local Util = require("rmux.utils")
local Integs = require("rmux.integrations")

local Picker = require("rmux.picker")

local M = {}

local use_default_provider = false

-- local function _run_tasks_all()
-- 	Integs:open_all_panes()
-- end

local function _run_grep_err()
	if use_default_provider then
		Util.warn("Cannot process, currently using the default provider (overseer)")
		return
	end
	Integs:find_err()
end

local function _run_file()
	if use_default_provider then
		Picker.load_overseer(Integs)
		return
	end
	Picker.load_tasks_list(Integs)
end

local function _open_repl()
	Integs:send_cmd()
end

local function _send_line()
	Integs:send_line()
end

local function _send_visual()
	Integs:send_line_range()
end

--  ────────────────────────────────────────────────────────────

local function _Xsend_interrupt()
	Integs:send_signal_interrupt()
end

-- local function _Xsend_interrupt_all()
-- 	require("rmux.integrations." .. Config.settings.base.run_with).send_interrupt(true)
-- end
--
local function _target_pane()
	if use_default_provider then
		Util.warn("Cannot process, currently using the default provider (overseer)")
		return
	end

	Integs:select_target_panes()
end

-- local function _Xedit_or_reload_config(isEdit, isFzf)
-- 	isEdit = isEdit or false
-- 	isFzf = isFzf or false
--
-- 	local file_rc = Config.settings.base.fullpath .. "/" .. Config.settings.base.file_rc
--
-- 	if not Util.exists(file_rc) then
-- 		if Config.settings.base.rmuxpath ~= nil and #Config.settings.base.rmuxpath > 0 then
-- 			Fzf.select_rmuxfile()
-- 		else
-- 			Util.info({
-- 				msg = "File " .. Config.settings.base.file_rc .. " is not exists\nlemme create that for you",
-- 				setnotif = true,
-- 			})
--
-- 			for _, value in pairs(vim.api.nvim_list_runtime_paths()) do
-- 				if value:match("runmux") then
-- 					file_rc = value .. "/lua/rmux/fts/base.json"
-- 				end
-- 			end
-- 			vim.cmd("e " .. Config.settings.base.file_rc)
-- 			vim.cmd("0r! cat " .. file_rc)
-- 			vim.cmd("0")
-- 		end
--
-- 		return
-- 	end
--
-- 	if isEdit then
-- 		if isFzf and Config.settings.base.rmuxpath ~= nil and #Config.settings.base.rmuxpath > 0 then
-- 			Fzf.select_rmuxfile()
-- 		else
-- 			vim.cmd("e " .. file_rc)
-- 		end
-- 	end
-- end
--
-- local function Xredit_config()
-- 	_Xedit_or_reload_config(true, true)
-- end

function _Xkill_all_panes()
	if use_default_provider then
		vim.cmd.OverseerToggle()
		return
	end
	Integs:close_all_panes()
end

--  ╭──────────────────────────────────────────────────────────╮
--  │                     FACTORY COMMAND                      │
--  ╰──────────────────────────────────────────────────────────╯

local tmpl = require("rmux.templates")

function M.command(state_cmd, dont_set_taskrc)
	dont_set_taskrc = dont_set_taskrc or false

	if not dont_set_taskrc then
		local taskrc = tmpl:register()
		local vscode = require("rmux.templates.vscode")
		local rmuxjson = require("rmux.templates.rmuxjson")
		local packagejson = require("rmux.templates.packagejson")
		taskrc:set_template({ vscode, rmuxjson, packagejson })
		Config.settings.tasks = {}

		if taskrc:is_load() then
			use_default_provider = false
		else
			use_default_provider = true

			if not use_default_provider then
				Util.info("File `tasks.json` does not exist. using the default provider: overseer")
			end
		end
	end

	assert(
		vim.tbl_contains(Config.settings.run_support_with, Config.settings.base.run_with),
		"Supported commands (`run_with`): " .. table.concat(Config.settings.run_support_with, ", ")
	)

	local run_with = Config.settings.base.run_with
	if run_with == "auto" then
		if os.getenv("TMUX") then
			Config.settings.base.run_with = "mux"
		else
			Config.settings.base.run_with = "wez"
		end
	else
		Config.settings.base.run_with = run_with
	end

	Integs:set_au_autokill()

	local call_cmds = {
		["run_file"] = _run_file,
		-- ["run_tasks_all"] = _run_tasks_all,
		["run_grep_err"] = _run_grep_err,

		["run_openrepl"] = _open_repl,

		["run_sendline"] = _send_line,
		["run_vsendline"] = _send_visual,

		["run_target_pane"] = _target_pane,

		["interrupt_single"] = _Xsend_interrupt,
		-- ["interrupt_all"] = _Xsend_interrupt_all,

		-- ["clear_all_pane_screen"] = _Xkill_all_panes,
		--
		-- ["edit_or_reload_config"] = _Xedit_or_reload_config,
		-- ["redit_config"] = Xredit_config,

		["kill_all_panes"] = _Xkill_all_panes,
	}

	if call_cmds[state_cmd] ~= nil then
		-- Prevent the user from editing or updating the current buffer temporarily by
		-- disabling user input and entering command-line mode.
		vim.api.nvim_input("<Cmd>")

		call_cmds[state_cmd]()

		-- Return to normal mode after the command is finished
		vim.api.nvim_input("<Esc>")
	else
		Util.warn(string.format("Provider command '%s' not implemented yet", state_cmd))
	end
end

return M
