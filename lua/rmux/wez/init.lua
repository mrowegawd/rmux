local Constant = require("rmux.constant")
local Util = require("rmux.utils")
local WezUtil = require("rmux.wez.util")
local Config = require("rmux.config")

local M = {}

local wezterm_send = "wezterm cli "

local current_pane_id

local function __respawn_pane()
	if WezUtil.get_total_active_panes() == 1 then
		local cur_pane_id = WezUtil.get_current_pane_id()

		local win_width = vim.api.nvim_get_option("columns")

		local w = math.floor((win_width * 0.2) + 1)
		if w < 30 then
			w = 40
		end

		vim.fn.system(string.format("wezterm cli split-pane --right --percent %s", w))
		-- wezterm cli split-pane --bottom --percent 50 -- sh -c "cargo test; read"

		WezUtil.back_to_pane(cur_pane_id)
		Constant.set_sendID(WezUtil.get_id_next_pane(cur_pane_id, true))
	end
end

function M.send_runfile(opts, state_cmd)
	-- `true` paksa spawn 1 pane, jika terdapat hanya satu pane saja yang active
	__respawn_pane()

	-- Check if `pane_target.pane_id` is not exists, we must update the `pane_target.pane_id`
	local tbl_opened_panes = Constant.get_tbl_opened_panes()
	local pane_id = tonumber(Constant.get_sendID())
	current_pane_id = pane_id

	if Util.tablelength(tbl_opened_panes) == 0 then
		if pane_id and (pane_id > 0) then
			local pane_num = WezUtil.get_pane_num(Constant.get_sendID())
			if WezUtil.pane_exists(pane_id) then
				local open_pane
				Constant.set_insert_tbl_opened_panes(
					tostring(pane_id),
					pane_num,
					open_pane,
					state_cmd,
					opts.command,
					opts.regex
				)
			end
			M.send_runfile(opts, state_cmd)
		else
			local cur_pane_id = WezUtil.get_current_pane_id()
			Constant.set_sendID(WezUtil.get_id_next_pane(cur_pane_id, true))
			M.send_runfile(opts, state_cmd)
		end
	else
		local cmd_nvim
		local cwd = vim.fn.expand("%:p:h")
		local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")

		local run_pane_tbl = Constant.find_state_cmd_on_tbl_opened_panes(state_cmd)
		if run_pane_tbl then
			-- Jika term_ops.pane_id dari table `Config.settings.base.tbl_opened_panes`
			-- yang berdasarkan `state_cmd` tidak exists, maka akan men-update table nya
			if not WezUtil.pane_exists(run_pane_tbl.pane_id) then
				pane_id = tonumber(Constant.get_sendID())
				if not WezUtil.pane_exists(pane_id) then
					Constant.set_sendID(WezUtil.get_pane_id(WezUtil.get_last_active_pane()))
					M.send_runfile(opts, state_cmd)
				end

				---@diagnostic disable-next-line: unused-local
				Constant.update_tbl_opened_panes(function(idx, pane)
					if pane.state_cmd == state_cmd then
						run_pane_tbl.pane_id = pane_id
						-- 		M.send_runfile(opts, state_cmd)
					end
				end)
			end

			cmd_nvim = wezterm_send .. "send-text --no-paste "

			if opts.include_cwd then
				cmd_nvim = cmd_nvim .. "'" .. run_pane_tbl.command .. " " .. cwd .. "/" .. fname .. "'"
			end

			cmd_nvim = cmd_nvim .. " --pane-id " .. run_pane_tbl.pane_id

			vim.fn.system(wezterm_send .. "send-text --no-paste $'clear' --pane-id " .. run_pane_tbl.pane_id)
			WezUtil.sendEnter(run_pane_tbl.pane_id)

			vim.fn.system(cmd_nvim)
			WezUtil.sendEnter(run_pane_tbl.pane_id)

			-- clear the screen pane
		else
			local tot_panes = WezUtil.get_total_active_panes()
			Constant.set_sendID(WezUtil.get_pane_id(tot_panes))
			local pane_num = WezUtil.get_pane_num(Constant.get_sendID())
			local open_pane
			Constant.set_insert_tbl_opened_panes(
				tostring(pane_id),
				pane_num,
				open_pane,
				state_cmd,
				opts.command,
				opts.regex
			)

			M.send_runfile(opts, state_cmd)
		end
	end
end

local function __close_all()
	local total_panes = WezUtil.get_total_active_panes()
	if current_pane_id ~= nil then
		current_pane_id = WezUtil.get_pane_id(WezUtil.get_current_pane_id())
	end

	if total_panes > 1 then
		for _, pane in pairs(Constant.get_tbl_opened_panes()) do
			vim.schedule(function()
				WezUtil.kill_pane(pane.pane_id)
			end)
		end
	end
end

function M.close_all_panes()
	current_pane_id = WezUtil.get_current_pane_id()

	__close_all()

	Config.settings.base.tbl_opened_panes = {}
	WezUtil.back_to_pane(current_pane_id)
end

function M.open_multi_panes(layouts, state_cmd)
	current_pane_id = WezUtil.get_current_pane_id()

	-- `open_multi_panes` di wez ini agak berbeda prilaku nya dengan tmux.
	--
	-- Kalau di tmux dengan code seperti ini, prilaku nya sama yang kita harapkan:
	-- tmux split-window -v -p 40
	-- tmux split-window -h -p 80
	-- tmux split-window -h -p 70
	-- tmux split-window -h -p 60
	--
	-- Kalau di wez, dengan code diatas jika ditulis seperti ini, prilaku nya akan berbeda:
	-- wezterm cli split-pane --bottom --percent 40
	-- wezterm cli split-pane --right --percent 80
	-- wezterm cli split-pane --right --percent 70
	-- wezterm cli split-pane --right --percent 60
	--
	-- Di wez harus merujuk `--pane-id` nya, jadi harus ditulis seperti ini:
	-- wezterm cli split-pane --bottom --percent 40 --pane-id (last-id)
	-- wezterm cli split-pane --right --percent 80 --pane-id (last-id)
	-- wezterm cli split-pane --right --percent 70 --pane-id (last-id)
	-- wezterm cli split-pane --right --percent 60 --pane-id (last-id)

	local set_pane_id = false
	for idx, layout in pairs(layouts) do
		if layout.open_pane ~= nil and #layout.open_pane > 0 then
			local layouts_idx = layouts[idx]

			local cmd_tbl = vim.split(layout.open_pane, " ")
			assert(vim.tbl_contains({ "-v", "-h" }, cmd_tbl[3]), "flag must be value: '-h', '-w'")
			assert(vim.tbl_contains({ "-p" }, cmd_tbl[4]), "flag must be value: '-p'")
			assert(type(tonumber(cmd_tbl[5])) == "number", "must be a number")

			local split_mode = "bottom"
			if cmd_tbl[3] == "-h" then
				split_mode = "right"
			end

			-- print(wezterm_send .. "split-pane --" .. split_mode .. " --percent " .. tonumber(cmd_tbl[5]))
			if not set_pane_id then
				vim.fn.system(wezterm_send .. "split-pane --" .. split_mode .. " --percent " .. cmd_tbl[5])
				set_pane_id = true
			else
				local pane_id = WezUtil.get_current_pane_id()
				vim.fn.system(
					wezterm_send
						.. "split-pane --"
						.. split_mode
						.. " --percent "
						.. cmd_tbl[5]
						.. " --pane-id "
						.. pane_id
				)
			end

			-- M.back_to_pane_one()
			-- vim.fn.system(wezterm_send .. "activate-pane --pane-id " .. cmd_tbl[5])

			local pane_num = WezUtil.get_current_pane_id()
			local pane_id = tostring(pane_num)

			Constant.set_insert_tbl_opened_panes(
				pane_id,
				pane_num,
				layouts_idx.open_pane,
				state_cmd,
				layouts_idx.command,
				layouts_idx.regex
			)
		else
			Util.warn({ msg = "Why did this happen?\n- There is no file .rmuxrc.json", setnotif = true })
		end
	end

	M.send_multi(state_cmd)
	M.back_to_pane_one()

	set_pane_id = false
end

function M.back_to_pane_one()
	if current_pane_id then
		WezUtil.back_to_pane(current_pane_id)
	end
end

function M.send_multi(state_cmd)
	for _, pane in pairs(Constant.get_tbl_opened_panes()) do
		if pane.state_cmd == state_cmd then
			vim.fn.system(
				wezterm_send .. "send-text --no-paste '" .. pane.command .. "'" .. " --pane-id " .. pane.pane_id
			)
			WezUtil.sendEnter(pane.pane_id)
		end
	end

	if type(Constant.get_sendID()) == "number" and Constant.get_sendID() > 0 then
		Constant.set_sendID(WezUtil.get_pane_id(WezUtil.get_total_active_panes()))
	end
end

return M
