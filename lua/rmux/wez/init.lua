local Constant = require("rmux.constant")
local Util = require("rmux.utils")
local WezUtil = require("rmux.wez.util")
local Config = require("rmux.config")
local Fzf = require("rmux.fzf")

local M = {}

local wezterm_send = "wezterm cli "

local current_pane_id

local function __respawn_pane()
	local pane_right, is_pane_right = WezUtil.get_right_active_pane()

	if not is_pane_right then
		local cur_pane_id = WezUtil.get_current_pane_id()

		local win_width = vim.api.nvim_get_option("columns")

		-- local w = math.floor((win_width * 0.2) + 1)
		-- if w < 30 then
		-- 	w = 40
		-- end

		local w = math.floor((win_width * 0.1) - 5)
		if w < 30 then
			w = 25
		end

		-- wezterm cli split-pane --bottom --percent 50 -- sh -c "cargo test; read"
		vim.fn.system(string.format("wezterm cli split-pane --right --percent %s", w))

		WezUtil.back_to_pane(cur_pane_id)
		pane_right, is_pane_right = WezUtil.get_right_active_pane()
	end

	Constant.set_sendID(tonumber(pane_right))
end

function M.send_runfile(opts, state_cmd)
	-- `true` paksa spawn 1 pane, jika terdapat hanya satu pane saja yang active
	__respawn_pane()

	-- Check if `pane_target.pane_id` is not exists, we must update the `pane_target.pane_id`
	local tbl_opened_panes = Constant.get_tbl_opened_panes()
	local pane_id = tonumber(Constant.get_sendID())

	if Util.tablelength(tbl_opened_panes) == 0 then
		if WezUtil.pane_exists(pane_id) then
			local open_pane
			Constant.set_insert_tbl_opened_panes(
				tostring(pane_id),
				tonumber(pane_id),
				open_pane,
				state_cmd,
				opts.command,
				opts.regex
			)
		end
	end

	local cmd_nvim
	local cwd = vim.fn.expand("%:p:h")
	local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")

	local run_pane_tbl = Constant.find_state_cmd_on_tbl_opened_panes(state_cmd)

	if run_pane_tbl then
		-- Update tbl if regex or pane_id is not exists
		if not WezUtil.pane_exists(run_pane_tbl.pane_id) or run_pane_tbl.regex ~= opts.regex then
			local pane_idc = tonumber(Constant.get_sendID())

			---@diagnostic disable-next-line: unused-local
			Constant.update_tbl_opened_panes(function(idx, pane)
				if pane.state_cmd == state_cmd then
					run_pane_tbl.pane_id = pane_idc
					run_pane_tbl.regex = opts.regex
				end
			end)
			return M.send_runfile(opts, state_cmd)
		end

		cmd_nvim = wezterm_send .. "send-text --no-paste '" .. run_pane_tbl.command

		if opts.include_cwd then
			cmd_nvim = cmd_nvim .. " " .. cwd .. "/" .. fname
		end

		cmd_nvim = cmd_nvim .. "'"

		cmd_nvim = cmd_nvim .. " --pane-id " .. run_pane_tbl.pane_id

		vim.fn.system(wezterm_send .. "send-text --no-paste $'clear' --pane-id " .. run_pane_tbl.pane_id)
		WezUtil.sendEnter(run_pane_tbl.pane_id)

		vim.fn.system(cmd_nvim)
		WezUtil.sendEnter(run_pane_tbl.pane_id)
	end
end

function M.send_line()
	__respawn_pane()

	local send_pane = Constant.get_sendID()

	local linenr = vim.api.nvim_win_get_cursor(0)[1]
	vim.cmd(string.format("silent! %s,%s :w !wezterm cli send-text --no-paste --pane-id %s", linenr, linenr, send_pane))
end

function M.send_visual()
	__respawn_pane()

	local send_pane = Constant.get_sendID()

	-- if WezUtil.pane_iszoom() then
	-- 	WezUtil.pane_toggle_zoom()
	-- end

	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", false, true, true), "nx", false)

	local b_line, b_col
	local e_line, e_col

	local mode = vim.fn.visualmode()

	---@diagnostic disable-next-line: deprecated
	b_line, b_col = unpack(vim.fn.getpos("'<"), 2, 3)
	---@diagnostic disable-next-line: deprecated
	e_line, e_col = unpack(vim.fn.getpos("'>"), 2, 3)

	if e_line < b_line or (e_line == b_line and e_col < b_col) then
		e_line, b_line = b_line, e_line
		e_col, b_col = b_col, e_col
	end

	local lines = vim.api.nvim_buf_get_lines(0, b_line - 1, e_line, false)

	if #lines == 0 then
		return
	end

	-- trim white space
	local i = 1
	while i <= #lines do
		if lines[i] == "" then
			table.remove(lines, i)
		else
			i = i + 1
		end
	end

	if mode == "\22" then
		local b_offset = math.max(1, b_col) - 1
		for ix, line in ipairs(lines) do
			-- On a block, remove all preciding chars unless b_col is 0/negative
			lines[ix] = vim.fn.strcharpart(line, b_offset, math.min(e_col, vim.fn.strwidth(line)))
		end
	elseif mode == "v" then
		local last = #lines
		local line_size = vim.fn.strwidth(lines[last])
		local max_width = math.min(e_col, line_size)
		if max_width < line_size then
			-- If the selected width is smaller then total line, trim the excess
			lines[last] = vim.fn.strcharpart(lines[last], 0, max_width)
		end

		if b_col > 1 then
			-- on a normal visual selection, if the start column is not 1, trim the beginning part
			lines[1] = vim.fn.strcharpart(lines[1], b_col - 1)
		end
	end

	vim.cmd(string.format("silent! %s,%s :w !wezterm cli send-text --no-paste --pane-id %s", b_line, e_line, send_pane))
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
function M.open_multi_panes(layouts, state_cmd)
	current_pane_id = WezUtil.get_current_pane_id()

	local pane_id
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
			if pane_id == nil then
				pane_id = Util.normalize_return(
					vim.fn.system(
						wezterm_send .. "split-pane --" .. split_mode .. " --percent " .. tostring(cmd_tbl[5])
					)
				)
			else
				pane_id = Util.normalize_return(
					vim.fn.system(
						wezterm_send
							.. "split-pane --"
							.. split_mode
							.. " --percent "
							.. cmd_tbl[5]
							.. " --pane-id "
							.. tostring(pane_id)
					)
				)
			end

			local pane_num = WezUtil.get_pane_num(pane_id)
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

function M.grep_string_pane()
	if Constant.get_sendID() == "" then
		Util.warn({ msg = "pane not active, abort", setnotif = true })
		return
	end

	local target_pane_num = WezUtil.get_pane_num(Config.settings.sendID)
	local target_pane_id = Config.settings.sendID

	local pane_target
	for _, panes in pairs(Constant.get_tbl_opened_panes()) do
		if panes.pane_id == target_pane_id then
			pane_target = panes
		end
	end

	if pane_target then
		vim.schedule(function()
			local output = {}
			local cmd = WezUtil.pane_capture(target_pane_num, pane_target.regex)
			if cmd.output ~= nil then
				local res = vim.split(cmd.output, "\n")
				for index = 2, #res - 1 do
					local item = res[index]
					if item ~= "" then
						table.insert(output, item)
					end
				end
			end

			if #output > 0 then
				Fzf.grep_err(output, WezUtil.get_pane_num(pane_target.pane_id))
			end
		end)
	end
end

return M
