local M = {}
local Constant = require("rmux.constant")
local Fzf = require("rmux.picker.fzf")
local Config = require("rmux.config")

local function title_formatter(str)
	str = str or ""
	local prefix_name = "RUN" .. string.upper(Config.settings.base.run_with)
	if #str == 0 then
		return prefix_name
	end
	return prefix_name .. ": " .. str
end

local function generator_select(Integs, tbl)
	vim.validate({ tbl = { tbl, "table" } })
	return Fzf.gen_select(Integs, tbl, title_formatter())
end

function M.load_tasks_list(Integs)
	local tasks = Constant.get_tasks()
	local task_names = {}
	for _, x in pairs(tasks) do
		if x["name"] then
			table.insert(task_names, x.name)
		end
	end
	generator_select(Integs, task_names)
end

function M.select_pane(Integs, opts)
	opts.title = title_formatter("Select Pane")
	Fzf.select_pane(Integs, opts)
end

function M.grep_err(Integs, cur_pane_id, target_panes, opts)
	opts.regex = opts.regex or "(([.\\w\\-~\\$@]+)(\\/?[\\w\\-@]+)+\\/?)\\.([\\w]+)(:\\d*:\\d*)?"
	opts.grep_cmd = opts.grep_cmd or "grep -oP"
	opts.results = opts.results or Integs.grep_err_output_commands(cur_pane_id, target_panes, opts)
	opts.title = title_formatter(opts.title)

	Fzf.grep_err(opts)
end

return M
