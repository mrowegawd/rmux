local Config = require("rmux.config")
local Util = require("rmux.utils")
local Integs = require("rmux.integrations")

local Picker = require("rmux.picker")

local M = {}

local use_default_provider = false

function M.grep_err()
	if use_default_provider then
		Util.warn("Cannot process, currently using the default provider (overseer)")
		return
	end
	Integs:find_err()
end

function M.grep_buf()
	Picker.grep_buf()
end

function M.run_file()
	if use_default_provider then
		Picker.load_overseer(Integs, true)
		return
	end
	Picker.load_tasks_list(Integs)
end

function M.send_line()
	Integs:send_line()
end

function M.send_vline()
	Integs:send_line_range()
end

function M.send_interrupt()
	Integs:send_signal_interrupt()
end

function M.show_config()
	print(vim.inspect(Config.settings))
end

function M.send_interrupt_all()
	Integs:send_signal_interrupt_all()
end

function M.target_pane()
	if use_default_provider then
		Util.warn("Cannot process, currently using the default provider (overseer)")
		return
	end

	Integs:select_target_panes()
end

function M.edit_config(is_select_file)
	is_select_file = is_select_file or false

	if is_select_file then
		Picker.selec_and_load_filerc()
		return
	end

	local run_with = Config.settings.base.run_with
	local file_rc = Config.settings.base.fullpath .. "/" .. Config.settings.base.file_rc

	if vim.tbl_contains({ "mux", "wez" }, run_with) then
		file_rc = ".vscode/tasks.json"
	end

	if not Util.exists(file_rc) then
		Util.warn("Provider '" .. run_with .. "' used, but .vscode/tasks.json not found")
		return
	end

	vim.cmd("vsp " .. file_rc)
end

function M.select_filerc()
	M.edit_config(true)
end

function M.kill_all_panes()
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

	local function _cmd()
		local cmd
		for _, provider_cmd in pairs(Config.settings.provider_cmd) do
			if state_cmd == provider_cmd then
				cmd = provider_cmd
			end
		end
		return cmd
	end

	local call = M[_cmd()]

	if call == nil then
		Util.error("Invalid '" .. tostring(state_cmd) .. "' API provider cmd!")
		return
	end

	-- Prevent the user from editing or updating the current buffer temporarily by
	-- disabling user input and entering command-line mode.
	vim.api.nvim_input("<Cmd>")

	call()

	-- Return to normal mode after the command is finished
	vim.api.nvim_input("<Esc>")
end

return M
