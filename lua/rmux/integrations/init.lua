local Config = require("rmux.config")
local Constant = require("rmux.constant")
local Util = require("rmux.utils")
local Picker = require("rmux.picker")

local Integs = {} -- Integs: integ

Integs.__index = Integs

function Integs:run()
	return require("rmux.integrations." .. Config.settings.base.run_with)
end

function Integs:__jump_to_main_pane(main_pane_id)
	vim.validate({ pane_id = { main_pane_id, "string" } })

	-- local cur_pane_id = self:run().get_current_pane_id()
	-- print("back to main pain? " .. cur_pane_id .. " " .. main_pane_id)
	-- if main_pane_id ~= cur_pane_id then
	self:run().jump_to_pane_id(main_pane_id)
	-- end
end

function Integs:run_file(name_cmd, type_strategy)
	local cur_pane_id = self:run().get_current_pane_id()
	local tbl_opened_panes = Constant.get_tbl_opened_panes()

	if #tbl_opened_panes == 0 and (self:run().get_total_active_panes() == 1) then
		self:_respawn_pane()
		tbl_opened_panes = Constant.get_tbl_opened_panes()
		local sendID = Constant.get_sendID()
		local pane_id = sendID
		local pane_idx = tonumber(self:run().get_pane_idx(pane_id))
		local builder
		for _, tasks in pairs(Constant.get_tasks()) do
			if tasks.name == name_cmd then
				builder = tasks.builder({})
			end
		end

		Constant.set_insert_tbl_opened_panes(pane_id, pane_idx, name_cmd, builder, type_strategy)

		local refresh_pane = true
		for _, task in pairs(tbl_opened_panes) do
			if task.type_strategy == type_strategy then
				if task.name == name_cmd then
					self:run().send_pane_cmd(task, refresh_pane)
				end
			end
		end

		self:__jump_to_main_pane(cur_pane_id)
		return
	end

	local _task
	for _, task in pairs(tbl_opened_panes) do
		if task.type_strategy == type_strategy then
			for _, pane_opened in pairs(self:run().get_lists_pane_id_opened()) do
				if task.pane_id == pane_opened and task.name == name_cmd then
					_task = task
				end
			end
		end
	end

	if _task == nil then
		self:_respawn_pane(true)
		tbl_opened_panes = Constant.get_tbl_opened_panes()
		local sendID = Constant.get_sendID()
		local pane_id = sendID
		local pane_idx = tonumber(self:run().get_pane_idx(pane_id))
		local builder
		for _, tasks in pairs(Constant.get_tasks()) do
			if tasks.name == name_cmd then
				builder = tasks.builder({})
			end
		end

		Constant.set_insert_tbl_opened_panes(pane_id, pane_idx, name_cmd, builder, type_strategy)

		local refresh_pane = true
		for _, task in pairs(tbl_opened_panes) do
			if task.type_strategy == type_strategy then
				if task.name == name_cmd then
					self:run().send_pane_cmd(task, refresh_pane)
				end
			end
		end

		self:__jump_to_main_pane(cur_pane_id)
		return
	end

	if _task.name == name_cmd then
		local refresh_pane = true
		self:run().send_pane_cmd(_task, refresh_pane)
		self:__jump_to_main_pane(cur_pane_id)
	end
end

function Integs:run_all(list_tasks, type_strategy)
	vim.validate({ list_tasks = { list_tasks, "table" }, type_strategy = { type_strategy, "string" } })

	local pane_strategy = "-v"
	local cur_pane_id = self:run().get_current_pane_id()

	for i, lang_task in pairs(Constant.get_tasks()) do
		local lang_task_name = lang_task.builder({}).name
		for _, task in pairs(list_tasks) do
			if lang_task_name == task then
				local pane_size = math.floor((self:run().get_pane_width() / i) + 70)

				if pane_strategy == "-v" then
					pane_size = 15
				end

				local pane_id = self:run().open_vertical_pane(pane_strategy, pane_size)
				local pane_idx = tonumber(self:run().get_pane_idx(pane_id))
				local builder = lang_task.builder({})
				local name_cmd = lang_task.builder({}).cmd

				if pane_strategy == "-v" then
					pane_strategy = "-h"
				end

				if type(name_cmd) == "string" then
					Constant.set_insert_tbl_opened_panes(pane_id, pane_idx, name_cmd, builder, type_strategy)
				end
			end
		end
	end

	self:run().reset_resize_pane(cur_pane_id)
	self:run().jump_to_pane_id(cur_pane_id)

	local tbl_opened_panes = Constant.get_tbl_opened_panes()
	if #tbl_opened_panes > 0 then
		for _, task in pairs(tbl_opened_panes) do
			if task.type_strategy == type_strategy then
				local refresh_pane = true

				self:run().send_pane_cmd(task, refresh_pane)
			end
		end

		self:run().jump_to_pane_id(cur_pane_id)
	end
end

function Integs:generator_cmd_panes(name_cmd)
	vim.validate({ opts = { name_cmd, "string" } })

	if #Constant.get_tasks() > 0 then
		for _, lang_task in pairs(Constant.get_tasks()) do
			if lang_task.name == name_cmd then
				-- type with: dependsOn("task 1", "task 2")
				if
					lang_task.builder({}).components
					and lang_task.builder({}).components[2].task_names
					and #lang_task.builder({}).components[2].task_names > 0
				then
					self:run_all(lang_task.builder({}).components[2].task_names, "orchestrator")
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

function Integs:_respawn_pane(expand_pane)
	expand_pane = expand_pane or false

	local total_panes = self:run().get_total_active_panes()
	if total_panes == 1 then
		self:run().create_new_pane(false)
	else
		self:run().create_new_pane(true)
	end
end

function Integs:send_line()
	self:_respawn_pane()
	self:run().send_line()
end

function Integs:send_line_range()
	self:_respawn_pane()
	self:run().send_range_line()
end

function Integs:select_target_panes(is_watcher)
	is_watcher = is_watcher or false

	local cur_pane_id = self:run().get_current_pane_id()

	local pane_lists = self:run().get_lists_pane_id_opened()

	if pane_lists and #pane_lists == 1 then
		Util.info({
			msg = "Only one pane is open. No action taken.",
			title = "RMUX",
			setnotif = true,
		})
		return
	end

	-- Remove pane_id from our main pane id
	local pane_opened = {}
	for _, pane_id in pairs(pane_lists) do
		if cur_pane_id ~= pane_id then
			pane_opened[#pane_opened + 1] = pane_id
		end
	end

	local tbl_taks_pane_opened = {}
	local tbl_opened_panes = Constant.get_tbl_opened_panes()
	for _, p_id in pairs(pane_opened) do
		for _, task in pairs(tbl_opened_panes) do
			if task.pane_id == p_id then
				tbl_taks_pane_opened[p_id] = {
					pane_id = task.pane_id,
					window_idx = task.pane_idx,
					builder = task.builder,
				}
			end
		end
		-- Add pane IDs that are not present in the table `tbl_opened_panes`
		if not tbl_taks_pane_opened[p_id] then
			tbl_taks_pane_opened[p_id] = {
				pane_id = p_id,
			}
		end
	end

	local list_panes = tbl_taks_pane_opened
	if Util.tablelength(tbl_taks_pane_opened) == 0 then
		list_panes = pane_opened
	end

	local opts = { results = list_panes, is_watcher = is_watcher }
	Picker.select_pane(Integs, opts)
end

function Integs:send_cmd() -- pengganti openREPL
	print("open send cmd")
end

function Integs:send_signal_interrupt()
	self:run().send_interrupt()
end

function Integs:watcher()
	self:select_target_panes(true)
end

function Integs:unset_augroup(name)
	vim.validate({ name = { name, "string" } })
	pcall(vim.api.nvim_del_augroup_by_name, name)
end

local augroup_name = "RmuxWatcher"
function Integs:set_au_watcher()
	if Constant.get_watcher_status() then
		Integs:unset_augroup(augroup_name) -- avoid duplicate augroup

		local augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })
		vim.api.nvim_create_autocmd("BufWritePre", {
			pattern = "*",
			group = augroup,
			callback = function()
				local selected_panes = Constant.get_selected_pane()
				local tbl_opened_panes = Constant.get_tbl_opened_panes()

				for _, pane_id in pairs(selected_panes) do
					if self:run().pane_exists(pane_id) then
						for _, task in pairs(tbl_opened_panes) do
							if task.pane_id == pane_id then
								self:run_file(task.name, "shell")
							end
						end
					end
				end
			end,
		})
	end
end

local augroupkill = "RmuxAutoKill"
local is_set_autokill = false
function Integs:set_au_autokill()
	if Config.settings.base.auto_kill and not is_set_autokill then
		-- Delete augroup if it already exists to prevent duplication
		Integs:unset_augroup(augroupkill)

		local augroup = vim.api.nvim_create_augroup(augroupkill, { clear = true })
		vim.api.nvim_create_autocmd("ExitPre", {
			pattern = "*",
			group = augroup,
			callback = function()
				Integs:close_all_panes()
			end,
		})
		is_set_autokill = true
	end
end

function Integs:find_err()
	local tbl_opened_panes = Constant.get_tbl_opened_panes()
	if #tbl_opened_panes == 0 then
		Util.info({ msg = "No task running", setnotif = true })
		return
	end

	local target_panes = {}
	local title_picker = "Grep Error "
	local cur_pane_id = self:run().get_current_pane_id()

	local selected_panes = Constant.get_selected_pane()
	if selected_panes and #selected_panes > 0 then
		target_panes = selected_panes
	else
		for _, task in pairs(tbl_opened_panes) do
			if task.pane_id then
				target_panes[#target_panes + 1] = task.pane_id
			end
		end
	end

	if #target_panes == 1 then
		title_picker = title_picker .. "Pane " .. target_panes[1]
	else
		title_picker = title_picker .. "Panes [ " .. table.concat(target_panes, " ") .. " ]"
	end

	local opts = { title = title_picker }
	Picker.grep_err(Integs.run(self), cur_pane_id, target_panes, opts)
end

function Integs:kill_pane(pane_id)
	vim.validate({ pane_id = { pane_id, "string" } })

	self:run().kill_pane(pane_id)
	-- Delete pane_id jika terdapat pada `tbl_opened_panes`
	Constant.remove_pane_from_opened(pane_id)
end

function Integs:close_all_panes()
	if self:run() == "default" then
		vim.cmd.OverseerToggle()
		return
	end

	local panes = Constant.get_tbl_opened_panes()
	if #panes > 0 then
		for _, pane in pairs(panes) do
			vim.schedule(function()
				self:run().kill_pane(pane.pane_id)
			end)
		end
	end

	Config.settings.base.tbl_opened_panes = {}
end

return Integs
