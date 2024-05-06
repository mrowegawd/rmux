local Config = require("rmux.config")
local Util = require("rmux.utils")
local Integs = require("rmux.integrations")

local Picker = require("rmux.picker")

local M = {}

local augroup = vim.api.nvim_create_augroup("RMUX_AUKILL", { clear = true })

local function _auto_kill()
	if Config.settings.base.auto_kill and Config.settings.base.run_with ~= "toggleterm" then
		vim.api.nvim_create_autocmd("ExitPre", {
			pattern = "*",
			group = augroup,
			callback = function()
				Integs:close_all_panes()
			end,
		})
	end
end

-- local function _run_tasks_all()
-- 	Integs:open_all_panes()
-- end

-- local function _run_grep_err()
-- 	require("rmux.integrations." .. Config.settings.base.run_with).grep_string_pane(Config.settings.sendID)
-- 	_auto_kill()
-- end

local function _run_file()
	Picker.load_tasks_list()
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
-- ---@diagnostic disable-next-line: unused-local
-- local function _Xchange_target_pane(opts)
-- 	if require("rmux.integrations." .. Config.settings.base.run_with .. ".util").get_total_active_panes() == 1 then
-- 		return Util.info({ msg = "No pane active", setnotif = true })
-- 	end
--
-- 	Fzf.target_pane()
-- end

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
	Integs:close_all_panes()
end

--  ╭──────────────────────────────────────────────────────────╮
--  │                     FACTORY COMMAND                      │
--  ╰──────────────────────────────────────────────────────────╯

local tmpl = require("rmux.templates")

local vscode = require("rmux.templates.vscode")
local rmuxjson = require("rmux.templates.rmuxjson")
local packagejson = require("rmux.templates.packagejson")

function M.command(opts, state_cmd)
	local taskrc = tmpl:register()
	taskrc:set_template({ vscode, rmuxjson, packagejson })
	Config.settings.langs = {}

	if taskrc:is_load() then
		-- NOTE: this for test, checking output Config.settings.langs
		-- for _, x in pairs(Config.settings.langs) do
		-- 	print(vim.inspect(x.builder({})))
		-- end

		assert(
			vim.tbl_contains(Config.settings.run_support_with, Config.settings.base.run_with),
			"supported commands (`run_with`): " .. table.concat(Config.settings.run_support_with, ", ")
		)

		if Config.settings.base.run_with == "mux" then
			if not os.getenv("TMUX") then
				Config.settings.base.run_with = "toggleterm"
			end
		end

		if Config.settings.base.run_with == "wez" then
			if os.getenv("TMUX") then
				Config.settings.base.run_with = "mux"
			end
		end

		_auto_kill()

		opts = opts or ""
		local call_cmds = {
			["run_file"] = _run_file,
			-- ["run_tasks_all"] = _run_tasks_all,
			-- ["run_grep_err"] = _run_grep_err,

			["run_openrepl"] = _open_repl,

			["run_sendline"] = _send_line,
			["run_vsendline"] = _send_visual,

			-- ["change_target_pane"] = _Xchange_target_pane,

			["interrupt_single"] = _Xsend_interrupt,
			-- ["interrupt_all"] = _Xsend_interrupt_all,

			-- ["clear_all_pane_screen"] = _Xkill_all_panes,
			--
			-- ["edit_or_reload_config"] = _Xedit_or_reload_config,
			-- ["redit_config"] = Xredit_config,

			["kill_all_panes"] = _Xkill_all_panes,
		}

		if call_cmds[state_cmd] ~= nil then
			return call_cmds[state_cmd]()
		else
			Util.warn({ msg = string.format("Provider cmds '%s' not implemented yet", state_cmd), setnotif = true })
		end
	end
end

return M
