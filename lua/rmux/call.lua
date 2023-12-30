local Config = require("rmux.config")
local Util = require("rmux.utils")
local Fzf = require("rmux.fzf")

local M = {}

local augroup = vim.api.nvim_create_augroup("RMUX_AUKILL", { clear = true })

local function _auto_kill()
	if Config.settings.base.auto_kill and Config.settings.base.run_with ~= "toggleterm" then
		vim.api.nvim_create_autocmd("ExitPre", {
			pattern = "*",
			group = augroup,
			callback = function()
				require("rmux." .. Config.settings.base.run_with).close_all_task_panes()
			end,
		})
	end
end

local function _run_tasks_all()
	local state_cmd = Config.settings.provider_cmd.RUN_TASKS_ALL
	local layouts = Config.settings.langs.tasks.layout

	require("rmux." .. Config.settings.base.run_with).open_multi_panes(layouts, state_cmd)
	_auto_kill()
end

local function _run_grep_err()
	require("rmux." .. Config.settings.base.run_with).grep_string_pane(Config.settings.sendID)

	_auto_kill()
end

local function _run_file()
	local state_cmd = Config.settings.provider_cmd.RUN_FILE
	require("rmux." .. Config.settings.base.run_with).send_runfile(Config.settings.langs.run_file, state_cmd)

	_auto_kill()
end

local function _open_repl()
	local state_cmd = Config.settings.provider_cmd.RUN_OPENREPL
	require("rmux." .. Config.settings.base.run_with).openREPL(Config.settings.langs.repl, state_cmd)
end

local function _send_line()
	require("rmux." .. Config.settings.base.run_with).send_line()
	_auto_kill()
end

local function _send_visual()
	require("rmux." .. Config.settings.base.run_with).send_visual()
	_auto_kill()
end

--  ────────────────────────────────────────────────────────────

local function _Xsend_interrupt()
	require("rmux." .. Config.settings.base.run_with).send_interrupt()
end

local function _Xsend_interrupt_all()
	require("rmux." .. Config.settings.base.run_with).send_interrupt(true)
end

---@diagnostic disable-next-line: unused-local
local function _Xchange_target_pane(opts)
	if require("rmux." .. Config.settings.base.run_with .. ".util").get_total_active_panes() == 1 then
		return Util.info({ msg = "No pane active", setnotif = true })
	end

	Fzf.target_pane()
end

local function _Xedit_or_reload_config(isEdit, isFzf)
	isEdit = isEdit or false
	isFzf = isFzf or false

	local file_rc = Config.settings.base.fullpath .. "/" .. Config.settings.base.file_rc

	if not Util.exists(file_rc) then
		if Config.settings.base.rmuxpath ~= nil and #Config.settings.base.rmuxpath > 0 then
			Fzf.select_rmuxfile()
		else
			Util.info({
				msg = "File " .. Config.settings.base.file_rc .. " is not exists\nlemme create that for you",
				setnotif = true,
			})

			for _, value in pairs(vim.api.nvim_list_runtime_paths()) do
				if value:match("runmux") then
					file_rc = value .. "/lua/rmux/fts/base.json"
				end
			end
			vim.cmd("e " .. Config.settings.base.file_rc)
			vim.cmd("0r! cat " .. file_rc)
			vim.cmd("0")
		end

		return
	end

	if isEdit then
		if isFzf and Config.settings.base.rmuxpath ~= nil and #Config.settings.base.rmuxpath > 0 then
			Fzf.select_rmuxfile()
		else
			vim.cmd("e " .. file_rc)
		end
	end
end

local function Xredit_config()
	_Xedit_or_reload_config(true, true)
end

function _Xkill_all_panes()
	require("rmux." .. Config.settings.base.run_with).close_all_panes()
end

--  ╭──────────────────────────────────────────────────────────╮
--  │                     FACTORY COMMAND                      │
--  ╰──────────────────────────────────────────────────────────╯

function M.command(opts, state_cmd)
	assert(
		vim.tbl_contains({ "mux", "tt", "toggleterm" }, Config.settings.base.run_with),
		"run_with must be a 'mux' or 'tt' "
	)

	if Config.settings.base.run_with == "mux" then
		if not os.getenv("TMUX") then
			Config.settings.base.run_with = "toggleterm"
		end
	end

	opts = opts or ""
	local call_cmds = {
		["run_file"] = _run_file,
		["run_tasks_all"] = _run_tasks_all,
		["run_grep_err"] = _run_grep_err,

		["run_openrepl"] = _open_repl,

		["run_sendid"] = _send_line,
		["run_vsendid"] = _send_visual,

		["change_target_pane"] = _Xchange_target_pane,

		["interrupt_single"] = _Xsend_interrupt,
		["interrupt_all"] = _Xsend_interrupt_all,

		["clear_all_pane_screen"] = _Xkill_all_panes,

		["edit_or_reload_config"] = _Xedit_or_reload_config,
		["redit_config"] = Xredit_config,

		["kill_all_panes"] = _Xkill_all_panes,
	}

	if call_cmds[state_cmd] ~= nil then
		return call_cmds[state_cmd](opts)
	else
		Util.warn({ msg = string.format("Provider cmds '%s' not implemented yet", state_cmd), setnotif = true })
	end
end

return M
