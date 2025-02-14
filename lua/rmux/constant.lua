local Config = require("rmux.config")

local M = {}

function M.insert_tbl_tasks(tbl_data_task)
	vim.validate({ tbl_data_langs = { tbl_data_task, "table" } })

	-- if #tbl_data_tasks == 0 then
	-- 	Config.settings.tasks = {}
	-- end

	for _, tasks in pairs(tbl_data_task) do
		table.insert(Config.settings.tasks, tasks)
	end
end

function M.set_insert_tbl_opened_panes(pane_id, pane_idx, name_cmd, builder, type_strategy)
	vim.validate({
		pane_id = { pane_id, "string", true },
		pane_idx = { pane_idx, "number", true },
		name_cmd = { name_cmd, "string", true },
		builder = { builder, "table", true },
		type_strategy = { type_strategy, "string", true },
	})
	return table.insert(Config.settings.base.tbl_opened_panes, {
		pane_id = pane_id,
		pane_idx = pane_idx,
		name = name_cmd,
		builder = builder,
		type_strategy = type_strategy,
	})
end

function M.get_tbl_opened_panes()
	return Config.settings.base.tbl_opened_panes
end

function M.update_tbl_opened_panes(fn)
	for idx, task in pairs(Config.settings.base.tbl_opened_panes) do
		fn(idx, task)
	end
end

---------------------

function M.set_sendID(send_pane)
	vim.validate({ send_pane = { send_pane, "string" } })
	Config.settings.sendID = send_pane
end

function M.get_sendID()
	return Config.settings.sendID
end

function M.get_tasks()
	return Config.settings.tasks
end

function M.set_selected_pane(panes_id)
	vim.validate({ panes_id = { panes_id, "table" } })
	Config.settings.base.selected_panes = panes_id
end

function M.get_selected_pane()
	return Config.settings.base.selected_panes
end

function M.set_watcher_status(status_watch)
	vim.validate({ status_watch = { status_watch, "boolean" } })
	if status_watch then
		Config.settings.base.is_watcher = status_watch
	end
end

function M.get_watcher_status()
	return Config.settings.base.is_watcher
end

---------------------
function M.find_state_cmd_on_tbl_opened_panes(state_cmd)
	-- assert(#Config.settings.base.tbl_opened_panes > 0, "get_tbl_opened_panes must greater than zero")
	for _, value in pairs(Config.settings.base.tbl_opened_panes) do
		if value.state_cmd == state_cmd then
			return value
		end
	end
end

return M
