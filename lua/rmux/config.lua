local M = {}

local default_settings = {
	base = {
		file_rc = ".rmuxrc.json",
		setnotif = true,
		auto_run_tasks = true,
		tbl_opened_panes = {},
		run_with = "mux", -- tmux, wez, tt, toggleterm (tt.nvim)
		auto_kill = true,
		size_pane = 12,
		rmuxpath = vim.fn.expand("~/.config/nvim/runmux"),
		quickfix = {
			copen = "belowright copen",
			lopen = "belowright lopen",
		},
	},
	tasks = {},
}

M.settings = {}

local function merge_settings(cfg_tbl, opts)
	opts = opts or {}
	local settings = vim.tbl_deep_extend("force", cfg_tbl, opts)
	return settings
end

function M.update_settings(opts)
	opts = opts or {}
	M.settings = merge_settings(default_settings, opts)

	M.settings.run_support_with = { "mux", "toggleterm", "wez", "termim", "auto" }
	M.settings.sendID = ""
	M.settings.provider_cmd = {
		RUN_FILE = "run_file",
		RUN_KILL_ALL_PANES = "kill_all_panes",

		RUN_SEND = "send_line",
		RUN_VSEND = "send_vline",
		RUN_INTERRUPT = "send_interrupt",
		RUN_INTERRUPT_ALL = "send_interrupt_all",

		RUN_GRAB_ERR = "grep_err",
		RUN_GRAB_BUF = "grep_buf",
		RUN_TARGET_PANE = "target_pane",

		RUN_EDIT_CONFIG = "edit_config",
		RUN_REDIT_CONFIG = "redit_config",
		RUN_SHOW_CONFIG = "show_config",
	}

	return M.settings
end

return M
