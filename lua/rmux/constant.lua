local Config = require("rmux.config")

local M = {}

function M.get_settings()
	return Config.settings
end

function M.get_settings_base()
	return Config.settings.base
end

function M.get_tasks()
	return Config.settings.tasks
end

function M.get_sendID()
	return Config.settings.sendID
end

function M.set_run_with(run_with)
	local base = M.get_settings_base()
	base.run_with = run_with
end

function M.get_run_with()
	local base = M.get_settings_base()
	return base.run_with
end

function M.insert_tbl_tasks(tbl_data_task)
	vim.validate({ tbl_data_langs = { tbl_data_task, "table" } })
	for _, tasks in pairs(tbl_data_task) do
		table.insert(M.get_tasks(), tasks)
	end
end

function M.insert_active_tasks(pane_id, pane_idx, name_cmd, builder, type_strategy)
	vim.validate({
		pane_id = { pane_id, "string", true },
		pane_idx = { pane_idx, "number", true },
		name_cmd = { name_cmd, "string", true },
		builder = { builder, "table", true },
		type_strategy = { type_strategy, "string", true },
	})
	return table.insert(Config.settings.base.active_tasks, {
		pane_id = pane_id,
		pane_idx = pane_idx,
		name = name_cmd,
		builder = builder,
		type_strategy = type_strategy,
	})
end

function M.get_active_tasks()
	local base = M.get_settings_base()
	return base.active_tasks
end

--Tweaking an item in the active_tasks list
function M.update_active_tasks(fn)
	local active_tasks = M.get_active_tasks()
	for idx, task in pairs(active_tasks) do
		fn(idx, task)
	end
end

function M.remove_from_active_tasks(pane_id)
	local active_tasks = M.get_active_tasks()
	for idx, pane in ipairs(active_tasks) do
		if pane.pane_id == pane_id then
			table.remove(active_tasks, idx)
			break
		end
	end
end

---------------------

function M.set_sendID(send_pane)
	vim.validate({ send_pane = { send_pane, "string" } })
	Config.settings.sendID = send_pane
end

function M.get_size_pane()
	local base = M.get_settings_base()
	return base.size_pane
end

function M.statusline_is_up(is_set)
	local base = M.get_settings_base()
	base.statusline = is_set
end

function M.get_statusline_status()
	local base = M.get_settings_base()
	return base.statusline
end

function M.set_selected_pane(panes_id)
	panes_id = panes_id or ""
	local base = M.get_settings_base()
	base.selected_pane = panes_id
end

function M.set_file_rc(file_rc)
	file_rc = file_rc or ""
	local base = M.get_settings_base()
	base.file_rc = file_rc
end

function M.get_file_rc()
	local base = M.get_settings_base()
	return base.file_rc
end

function M.get_selected_pane()
	local base = M.get_settings_base()
	return base.selected_pane
end

function M.set_watcher_status(status_watch)
	vim.validate({ status_watch = { status_watch, "boolean" } })
	local base = M.get_settings_base()
	base.is_watcher = status_watch
end

function M.get_watcher_status()
	local base = M.get_settings_base()
	return base.is_watcher
end

function M.get_dir_filerc()
	local base = M.get_settings_base()
	return base.rmuxpath
end

function M.get_template_provider()
	local base = M.get_settings_base()
	return base.provider
end

function M.set_template_provider(provider_name)
	vim.validate({ provider_name = { provider_name, "string" } })
	local base = M.get_settings_base()
	base.provider = provider_name
end

function M.open_qf()
	local base = M.get_settings_base()
	return base.quickfix.copen
end

function M.open_loc()
	local base = M.get_settings_base()
	return base.quickfix.lopen
end

---------------------
function M.find_state_cmd_on_tbl_opened_panes(state_cmd)
	-- assert(#Config.settings.base.active_tasks > 0, "get_active_tasks must greater than zero")
	local active_tasks = M.get_active_tasks()
	for _, value in pairs(active_tasks) do
		if value.state_cmd == state_cmd then
			return value
		end
	end
end

return M
