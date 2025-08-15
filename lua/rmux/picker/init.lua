local M = {}

local Constant = require("rmux.constant")
local Fzf = require("rmux.picker.fzf")
local Config = require("rmux.config")
local Util = require("rmux.utils")

local function title_formatter(str)
	str = str or ""
	local prefix_name = "RUN" .. string.upper(Config.settings.base.run_with)
	if #str == 0 then
		return prefix_name
	end
	return prefix_name .. ": " .. str
end

function M.load_tasks_list(Integs)
	local tasks = Constant.get_tasks()
	local task_names = {}
	for _, x in pairs(tasks) do
		if x["name"] then
			table.insert(task_names, x.name)
		end
	end

	Fzf.gen_select(Integs, task_names, title_formatter(), false)
end

function M.load_overseer(Integs, is_overseer)
	local global_commands = vim.api.nvim_get_commands({})
	local overseer_cmds = {}
	for idx, _ in pairs(global_commands) do
		if idx:find("Overseer*") then
			overseer_cmds[#overseer_cmds + 1] = idx
		end
	end

	Fzf.gen_select(Integs, overseer_cmds, title_formatter("overseer"), is_overseer)
end

function M.select_pane(Integs, opts)
	opts.title = title_formatter("Select Pane")

	Fzf.select_pane(Integs, opts)
end

function M.grep_err(Integs, Integs_tmpl_cmd, cur_pane_id, target_panes, opts, is_overseer)
	opts.regex = opts.regex or "(([.\\w\\-~\\$@]+)(\\/?[\\w\\-@]+)+\\/?)\\.([\\w]+)(:\\d*:\\d*)?"
	opts.grep_cmd = opts.grep_cmd or "grep -oP"
	opts.results = opts.results or Integs_tmpl_cmd.grep_err_output_commands(cur_pane_id, target_panes, opts)
	opts.title = title_formatter(opts.title)

	Fzf.grep_err(Integs, opts, is_overseer)
end

return M
