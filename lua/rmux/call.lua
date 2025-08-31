local Constant = require("rmux.constant")

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
	Util.info(vim.inspect(Constant.get_settings()))
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

	local run_with = Constant.get_run_with()
	local file_rc = Constant.get_file_rc()

	if run_with == "overseer" then
		local msg = "No RC file is required when using '" .. run_with .. "'"
		if is_select_file then
			msg = "There is no need to select an RC file"
		end

		Util.warn(msg)
		return
	end

	if not Util.exists(file_rc) then
		Util.warn("Provider '" .. run_with .. "' is used, but RC file '" .. file_rc .. "' was not found")
		return
	end

	if is_select_file then
		Picker.selec_and_load_filerc()
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

-- Only run notification once per session
local has_shown_notification = false

local function notification_popup(provider)
	Util.info("Using the default provider: " .. provider)
end

local function show_notification_once(provider)
	if not has_shown_notification then
		has_shown_notification = true
		notification_popup(provider)
	end
end

--  ╭──────────────────────────────────────────────────────────╮
--  │                     FACTORY COMMAND                      │
--  ╰──────────────────────────────────────────────────────────╯

local tmpl = require("rmux.templates")

function M.command(state_cmd)
	local Settings = Constant.get_settings()
	local Base = Settings.base

	local taskrc = tmpl:register()

	local vscode = require("rmux.templates.vscode")
	local rmuxjson = require("rmux.templates.rmuxjson")
	local packagejson = require("rmux.templates.packagejson")

	taskrc:set_template({ vscode, rmuxjson, packagejson })

	Settings.tasks = {}

	if taskrc:is_load() then
		use_default_provider = false
	else
		use_default_provider = true
	end

	local run_with = Base.run_with
	local run_support_with = Settings.run_support_with

	assert(
		vim.tbl_contains(run_support_with, run_with),
		"Supported commands (`run_with`): " .. table.concat(run_support_with, ", ")
	)

	if use_default_provider then
		Constant.set_run_with("overseer")
		Constant.set_template_provider("overseer")
		Constant.set_file_rc()
	end

	if not use_default_provider and (run_with == "auto" or run_with == "overseer") then
		local is_tmux = os.getenv("TMUX") ~= nil
		Constant.set_run_with(is_tmux and "mux" or "wez")
	end

	-- Only show once per session
	show_notification_once(Constant.get_run_with())

	Integs:set_au_autokill()

	local function _cmd()
		local cmd
		for _, provider_cmd in pairs(Settings.provider_cmd) do
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
