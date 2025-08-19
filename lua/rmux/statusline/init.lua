local Config = require("rmux.config")
local Constant = require("rmux.constant")

local M = {}

local function remove_percent(s)
	return vim.split(s:gsub("%%", ""), " ")[1]
end

local function capitalize_first_letter(str)
	return (str:gsub("^%l", string.upper))
end

function M.get()
	local Integs = require("rmux.integrations")

	local statusline_status = Constant.get_statusline_status()
	if statusline_status == nil then
		Constant.statusline_is_up(true)
	end

	Integs:update_rmux()

	local status = { task = 0, run_with = "", watch = "" }

	local tbl_active_tasks = Constant.get_active_tasks()

	if tbl_active_tasks and #tbl_active_tasks > 0 then
		status.task = #tbl_active_tasks
	end

	local run_with = Config.settings.base.run_with
	if run_with and #run_with > 0 then
		run_with = capitalize_first_letter(run_with)
		status.run_with = run_with
	end

	local selected_pane = Constant.get_selected_pane()
	if selected_pane then
		status.watch = remove_percent(selected_pane)
	end

	return status
end

return M
