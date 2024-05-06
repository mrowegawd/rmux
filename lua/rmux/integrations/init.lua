local Config = require("rmux.config")
local Constant = require("rmux.constant")
local Integs = {} -- Integs: integ
Integs.__index = Integs

function Integs:run_file(name_cmd, type_strategy)
	vim.validate({
		name_cmd = { name_cmd, "string" },
		type_strategy = { type_strategy, "string" },
	})

	local cur_pane_idx = require("rmux.integrations." .. Config.settings.base.run_with).get_current_pane_id()

	local right_pane_id = require("rmux.integrations." .. Config.settings.base.run_with).check_right_pane_id()
	local right_pane_idx = require("rmux.integrations." .. Config.settings.base.run_with).get_pane_idx(right_pane_id)

	if right_pane_idx ~= cur_pane_idx then
		require("rmux.integrations." .. Config.settings.base.run_with).back_to_pane(cur_pane_idx)
		Constant.set_sendID(right_pane_id)
	else
		self:_respawn_pane()
	end

	local tbl_opened_panes = Constant.get_tbl_opened_panes()
	local sendID = Constant.get_sendID()

	local builder
	if #tbl_opened_panes == 0 then
		if require("rmux.integrations." .. Config.settings.base.run_with).pane_exists(sendID) then
			local pane_id = sendID
			local pane_idx =
				tonumber(require("rmux.integrations." .. Config.settings.base.run_with).get_pane_idx(pane_id))

			for _, task_lang in pairs(Constant.get_langs()) do
				if task_lang.name == name_cmd then
					builder = task_lang.builder({})
				end
			end

			Constant.set_insert_tbl_opened_panes(pane_id, pane_idx, name_cmd, builder, type_strategy)
		end
	else
		local notfound = false
		for _, task in pairs(tbl_opened_panes) do
			if task.type_strategy == type_strategy then
				if task.pane_id == sendID then
					-- print("insert task")
					Constant.update_tbl_opened_panes(function(_, taskid)
						for _, lang_task in pairs(Constant.get_langs()) do
							if lang_task.name == name_cmd then
								require("rmux.integrations." .. Config.settings.base.run_with).update_keys_task(
									taskid,
									lang_task
								)
							end
						end
					end)
				end
			else
				notfound = true
			end
		end

		if notfound then
			if require("rmux.integrations." .. Config.settings.base.run_with).pane_exists(sendID) then
				local pane_id = sendID
				local pane_idx =
					tonumber(require("rmux.integrations." .. Config.settings.base.run_with).get_pane_idx(pane_id))

				for _, task_lang in pairs(Constant.get_langs()) do
					if task_lang.name == name_cmd then
						builder = task_lang.builder({})
					end
				end

				Constant.set_insert_tbl_opened_panes(pane_id, pane_idx, name_cmd, builder, type_strategy)
			end
		end
	end

	require("rmux.integrations." .. Config.settings.base.run_with).back_to_pane(cur_pane_idx)

	for _, task in pairs(tbl_opened_panes) do
		if task.type_strategy == type_strategy then
			if task.name == name_cmd then
				local pane_id = task.pane_id

				if not require("rmux.integrations." .. Config.settings.base.run_with).pane_exists(pane_id) then
					pane_id = Constant.get_sendID()
					task.pane_id = pane_id
				end
				local cmd_msg = task.builder.cmd
				local refresh_pane = true

				require("rmux.integrations." .. Config.settings.base.run_with).send_pane_cmd(
					pane_id,
					cmd_msg,
					refresh_pane
				)
			end
		end
	end

	require("rmux.integrations." .. Config.settings.base.run_with).back_to_pane(cur_pane_idx)
end

function Integs:run_all(list_tasks, type_strategy)
	vim.validate({
		list_tasks = { list_tasks, "table" },
		type_strategy = { type_strategy, "string" },
	})

	local cur_pane_idx = require("rmux.integrations." .. Config.settings.base.run_with).get_current_pane_id()

	local tasks_label = list_tasks.builder({}).strategy.tasks
	local pane_strategy = "-v"

	-- local open_panes = {}
	for i, label in pairs(tasks_label[1]) do
		for _, task_lang in pairs(Constant.get_langs()) do
			if task_lang.name == label then
				local pane_size = math.floor(
					(require("rmux.integrations." .. Config.settings.base.run_with).get_pane_width() / i) + 70
				)

				if pane_strategy == "-v" then
					pane_size = 15
				end

				local pane_id = require("rmux.integrations." .. Config.settings.base.run_with).open_vertical_pane(
					pane_strategy,
					pane_size
				)

				local pane_idx =
					tonumber(require("rmux.integrations." .. Config.settings.base.run_with).get_pane_idx(pane_id))

				local builder = task_lang.builder({})

				-- table.insert(open_panes, {
				-- 	pane_label = label,
				-- 	state = pane_strategy,
				-- 	pane_size = pane_size,
				-- })

				if pane_strategy == "-v" then
					pane_strategy = "-h"
				end

				Constant.set_insert_tbl_opened_panes(pane_id, pane_idx, label, builder, type_strategy)
			end
		end
	end

	require("rmux.integrations." .. Config.settings.base.run_with).back_to_pane(cur_pane_idx)

	local tbl_opened_panes = Constant.get_tbl_opened_panes()
	for _, task in pairs(tbl_opened_panes) do
		if task.type_strategy == type_strategy then
			local pane_id = task.pane_id
			local cmd_msg = task.builder.cmd
			local refresh_pane = true

			require("rmux.integrations." .. Config.settings.base.run_with).send_pane_cmd(
				pane_id,
				cmd_msg,
				refresh_pane,
				type_strategy
			)
		end
	end

	require("rmux.integrations." .. Config.settings.base.run_with).back_to_pane(cur_pane_idx)
end

function Integs:generator_cmd_panes(name_cmd)
	vim.validate({
		opts = { name_cmd, "string" },
	})
	if #Constant.get_langs() > 0 then
		for _, lang_task in pairs(Constant.get_langs()) do
			if lang_task.name == name_cmd then
				-- type with: dependsOn("task 1", "task 2")
				if lang_task.builder({}).strategy and (lang_task.builder({}).strategy[1] == "orchestrator") then
					self:run_all(lang_task, "dependsOn")
				end

				-- type: process
				if type(lang_task.builder({}).cmd) == "table" then
					print("its process tasks")
				end

				-- type: shell
				if type(lang_task.builder({}).cmd) == "string" then
					self:run_file(name_cmd, "shell")
				end
			end
		end
	end
end

function Integs:_respawn_pane()
	-- local total_panes = require("rmux.integrations." .. Config.settings.base.run_with).get_total_active_panes()

	-- if total_panes == 1 then
	require("rmux.integrations." .. Config.settings.base.run_with).create_new_pane()
	-- elseif total_panes == 2 then
	-- 	require("rmux.integrations." .. Config.settings.base.run_with).get_left_pane()
	-- end

	-- print(require("rmux.integrations." .. Config.settings.base.run_with).check_right_pane_current_command())
end

function Integs:send_line()
	self:_respawn_pane()
	require("rmux.integrations." .. Config.settings.base.run_with).send_line()
end

function Integs:send_line_range()
	self:_respawn_pane()
	require("rmux.integrations." .. Config.settings.base.run_with).send_range_line()
end

function Integs:send_cmd() -- pengganti openREPL
	print("open send cmd")
end

function Integs:send_signal_interrupt()
	require("rmux.integrations." .. Config.settings.base.run_with).send_interrupt()
end

function Integs:close_all_panes()
	local panes = Constant.get_tbl_opened_panes()
	if #panes > 0 then
		for _, pane in pairs(panes) do
			vim.schedule(function()
				require("rmux.integrations." .. Config.settings.base.run_with).kill_pane(pane.pane_id)
			end)
		end
	end

	Config.settings.base.tbl_opened_panes = {}
end

return Integs
