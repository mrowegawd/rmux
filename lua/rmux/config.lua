local M = {}

local default_settings = {
	base = {
		file_rc = ".rmuxrc.json",
		setnotif = true,
		auto_run_tasks = true,
		tbl_opened_panes = {},
		run_with = "mux", -- tmux, wez, tt, toggleterm (tt.nvim)
		auto_kill = true,
		rmuxpath = vim.fn.expand("~/.config/nvim/runmux"),
	},
	langs = {},
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

	M.settings.prefix_title = "RMUX"
	M.settings.run_support_with = { "mux", "tt", "toggleterm", "wez" }
	M.settings.sendID = ""
	M.settings.provider_cmd = {
		RUN_FILE = "run_file",
		RUN_TASKS_ALL = "run_tasks_all",
		RUN_OPENREPL = "run_openrepl",

		RUN_SENDID = "run_sendid",
		RUN_VSENDID = "run_vsendid",

		RUN_NONTMUX = "run_non_tmux",

		RUN_INTERRUPT = "interrupt_single", -- default nya harus false, jangan diubah menjadi true
		RUN_INTERRUPT_ALL = "interrupt_all",

		RUN_KILL_ALL_PANES = "kill_all_panes",

		RUN_GRAB_ERR = "run_grep_err",
	}

	return M.settings
end

return M
