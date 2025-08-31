local Config = require("rmux.config")
local Constant = require("rmux.constant")
local Util = require("rmux.utils")
local Picker = require("rmux.picker")
local Problem_matcher = require("overseer.template.vscode.problem_matcher")

local is_not_run_overseer = function()
	return not vim.tbl_contains(Config.settings.run_support_with, Config.settings.base.run_with)
end

local loop_panes = function(func)
	local panes = Constant.get_active_tasks()
	if #panes > 0 then
		for _, pane in pairs(panes) do
			vim.schedule(function()
				func(pane)
			end)
		end
	end
end

local Integs = {} -- Integs: integ

Integs.__index = Integs

function Integs:run()
	return require("rmux.integrations." .. Config.settings.base.run_with)
end

function Integs:__jump_to_main_pane(main_pane_id)
	vim.validate({ pane_id = { main_pane_id, "string" } })
	self:run().jump_to_pane_id(main_pane_id)
end

function Integs:spawn_pane(name_cmd, type_strategy, tbl_active_tasks, cur_pane_id, is_respawn_pane)
	vim.validate({ name_cmd = { name_cmd, "string" } }, { type_strategy = { type_strategy, "string" } })

	tbl_active_tasks = tbl_active_tasks or {}

	if is_respawn_pane then
		self:_respawn_pane()
	end

	local sendID = Constant.get_sendID()
	local pane_id = sendID
	local pane_idx = self:run().get_pane_idx_from_id(pane_id)

	local builder
	for _, tasks in pairs(Constant.get_tasks()) do
		if tasks.name == name_cmd then
			builder = tasks.builder({})
		end
	end

	if cur_pane_id == pane_id then
		Util.error("Run file aborted: 'cur_pane_id' and 'pane_id' cannot have the same value.")
		return
	end

	Constant.insert_active_tasks(pane_id, pane_idx, name_cmd, builder, type_strategy)

	Constant.set_selected_pane(pane_id)

	for _, task in pairs(tbl_active_tasks) do
		if task.type_strategy == type_strategy then
			if task.name == name_cmd then
				self:run().send_pane_cmd_task(task, is_clear_sceen)
			end
		end
	end

	self:__jump_to_main_pane(cur_pane_id)
end

function Integs:update_rmux(pane_id)
	pane_id = pane_id or ""

	local statusline_status = Constant.get_statusline_status()
	if statusline_status and not statusline_status then
		return
	end

	if pane_id and #pane_id > 0 then
		if not self:run().is_pane_exists(pane_id) then
			Constant.remove_from_active_tasks(pane_id)
		end
	end

	local selected_pane = Constant.get_selected_pane()

	if selected_pane and #selected_pane > 0 then
		if not self:run().is_pane_exists(selected_pane) then
			Constant.set_selected_pane()
			Constant.remove_from_active_tasks(selected_pane)
		end
	end

	local tbl_active_tasks = Constant.get_active_tasks()
	if tbl_active_tasks and #tbl_active_tasks > 0 then
		for _, task in pairs(tbl_active_tasks) do
			if not self:run().is_pane_exists(task.pane_id) then
				Constant.remove_from_active_tasks(task.pane_id)
			end
		end
	end
end

function Integs:run_file(name_cmd, type_strategy)
	local is_clear_sceen = true

	local cur_pane_id = self:run().get_current_pane_id()
	local tbl_active_tasks = Constant.get_active_tasks()

	self:update_rmux()

	if #tbl_active_tasks == 0 and (self:run().get_total_active_panes() == 1) then
		local respawn_pane = true
		self:spawn_pane(name_cmd, type_strategy, tbl_active_tasks, cur_pane_id, respawn_pane)
		return
	end

	local _task
	for _, task in pairs(tbl_active_tasks) do
		if task.type_strategy == type_strategy then
			for _, pane_id_open in pairs(self:run().get_lists_pane_id_opened()) do
				if task.pane_id == pane_id_open and task.name == name_cmd then
					_task = task
				end
			end
		end
	end

	if _task == nil then
		local respawn_pane = true
		self:spawn_pane(name_cmd, type_strategy, tbl_active_tasks, cur_pane_id, respawn_pane)
	end

	if _task and _task.name == name_cmd then
		self:run().send_pane_cmd_task(_task, is_clear_sceen)
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
				local pane_idx = self:run().get_pane_idx_from_id(pane_id)
				local builder = lang_task.builder({})
				local name_cmd = lang_task.builder({}).cmd

				if pane_strategy == "-v" then
					pane_strategy = "-h"
				end

				if type(name_cmd) == "string" then
					Constant.insert_active_tasks(pane_id, pane_idx, name_cmd, builder, type_strategy)
				end
			end
		end
	end

	self:run().reset_size_pane()
	self:run().jump_to_pane_id(cur_pane_id)

	loop_panes(function(pane)
		if pane.type_strategy == type_strategy then
			local is_clear_sceen = true
			self:run().send_pane_cmd_task(pane, is_clear_sceen)
			self:run().jump_to_pane_id(cur_pane_id)
		end
	end)
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

	local cwd = vim.fn.getcwd()

	local total_panes = self:run().get_total_active_panes()

	if total_panes == 1 then
		self:run().create_new_pane(cwd, false)
	else
		self:run().create_new_pane(cwd, true)
	end
end

function Integs:send_line()
	local selected_pane = Constant.get_selected_pane()
	if not selected_pane or (#selected_pane == 0) then
		Integs:select_target_panes()
		return
	end
	self:run().send_line(selected_pane)
end

function Integs:send_line_range()
	local selected_pane = Constant.get_selected_pane()
	if not selected_pane or (#selected_pane == 0) then
		Integs:select_target_panes()
		return
	end
	self:run().send_range_line(selected_pane)
end

function Integs:select_target_panes(is_watcher)
	is_watcher = is_watcher or false

	local opts = self:run().fzf_select_panes(is_watcher)
	if opts then
		Picker.select_pane(Integs, opts)
	end
end

function Integs:send_cmd() -- pengganti openREPL
	print("open send cmd")
end

function Integs:send_signal_interrupt()
	local selected_pane = Constant.get_selected_pane()
	if not selected_pane or (#selected_pane == 0) then
		Integs:select_target_panes()
		return
	end

	self:run().send_interrupt(selected_pane)
end

function Integs:send_signal_interrupt_all()
	loop_panes(function(pane)
		self:run().send_interrupt(pane.pane_id)
	end)
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
	Integs:unset_augroup(augroup_name) -- avoid duplicate augroup

	if Constant.get_watcher_status() then
		local augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", {
			pattern = "*",
			group = augroup,
			callback = function()
				local selected_pane = Constant.get_selected_pane()
				local tbl_active_tasks = Constant.get_active_tasks()

				if self:run().is_pane_exists(selected_pane) then
					for _, task in pairs(tbl_active_tasks) do
						if task.pane_id == selected_pane then
							self:run_file(task.name, "shell")
						end
					end
				end
			end,
		})
	end
end

local augroupkill = "RmuxAutoKill"
function Integs:set_au_autokill()
	local augroup = vim.api.nvim_create_augroup(augroupkill, { clear = true })
	vim.api.nvim_create_autocmd("ExitPre", {
		pattern = "*",
		group = augroup,
		callback = function()
			Integs:close_all_panes()
		end,
	})
end

function Integs:find_err()
	local tbl_active_tasks = Constant.get_active_tasks()
	if #tbl_active_tasks == 0 then
		Util.warn("No task running")
		return
	end

	local opts = { title = "Grep Error" }
	local cur_pane_id = self:run().get_current_pane_id()

	local selected_pane = Constant.get_selected_pane()
	if not selected_pane or (#selected_pane == 0) then
		Integs:select_target_panes()
		return
	end

	-- if #selected_pane > 0 then
	-- 	target_panes = selected_pane
	-- else
	-- 	for _, task in pairs(tbl_active_tasks) do
	-- 		if task.pane_id then
	-- 			if target_panes[task.pane_id] ~= nil then
	-- 				target_panes[#target_panes + 1] = task.pane_id
	-- 			end
	-- 		end
	-- 	end
	-- end

	for _, task in pairs(tbl_active_tasks) do
		-- TODO: set warning jika task.pane_id  tidak sama yang di select dan juga
		if task.pane_id and task.pane_id == selected_pane then
			local pm = Problem_matcher.resolve_problem_matcher(task.builder.components[1].problem_matcher)
			-- TODO: hentikan pm jika tidak ada atau nil, hentikan grep err nya
			if pm then
				local parser_defn = Problem_matcher.get_parser_from_problem_matcher(pm, {})
				opts.regex = parser_defn
			end
		end
	end

	-- TODO: resize pane dahulu jika berjalan di tmux, karena pane width kecil ga bisa di grab secara optimal
	-- > get size pane
	-- tmux display -p "#{pane_width}x#{pane_height}"
	-- > Ubah tinggi pane jadi 20 baris
	-- tmux resize-pane -y 20
	-- > Ubah lebar pane jadi 80 kolom
	-- tmux resize-pane -x 80

	-- if #target_panes == 1 then
	opts.title = opts.title .. " Pane " .. selected_pane
	-- else
	-- 	opts.title = opts.title .. " Panes [ " .. table.concat(target_panes, " ") .. " ]"
	-- end

	local is_overseer = is_not_run_overseer()

	Picker.grep_err(Integs, Integs.run(self), cur_pane_id, selected_pane, opts, is_overseer)
end

function Integs:kill_pane(pane_id)
	vim.validate({ pane_id = { pane_id, "string" } })

	self:run().kill_pane(pane_id)

	self:update_rmux(pane_id)
end

function Integs:close_all_panes(is_only_settings)
	is_only_settings = is_only_settings or false

	if self:run() == "default" then
		vim.cmd.OverseerToggle()
		return
	end

	if not is_only_settings then
		loop_panes(function(pane)
			self:run().kill_pane(pane.pane_id)
		end)
	end

	Constant.set_selected_pane()
	Constant.set_watcher_status(false)
	Config.settings.base.active_tasks = {}
end

return Integs
