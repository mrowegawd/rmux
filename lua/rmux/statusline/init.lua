local Config = require("rmux.config")
-- local Util = require("rmux.utils")
local Constant = require("rmux.constant")

local M = {}

local function remove_percent(s)
	return vim.split(s:gsub("%%", ""), " ")[1]
end

local function capitalize_first_letter(str)
	return (str:gsub("^%l", string.upper))
end

function M.get()
	local status = { task = 0, run_with = "", watch = "" }

	if #Constant.get_tbl_opened_panes() > 0 then
		local task = #Constant.get_tbl_opened_panes()
		if tonumber(task) > 0 then
			status.task = task
		end
	end

	if #Config.settings.base.run_with > 0 then
		local run_with = capitalize_first_letter(Config.settings.base.run_with)
		if run_with then
			status.run_with = run_with
		end
	end

	local selected_panes = Constant.get_selected_pane()
	local selected = {}
	if selected_panes and #selected_panes > 0 then
		for _, value in ipairs(selected_panes) do
			local watch = remove_percent(value)
			selected[#selected + 1] = watch
		end

		if selected and #selected > 0 then
			status.watch = selected
		end
	end

	return status
end

return M
