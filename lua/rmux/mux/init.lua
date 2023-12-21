local Util = require("rmux.utils")
local Config = require("rmux.config")
local MuxUtil = require("rmux.mux.util")
local Fzf = require("rmux.fzf")

local M = {}

local tmux_send = "tmux send -t "

local current_pane_id

local function __respawn_pane(send_pane)
	if MuxUtil.get_total_active_panes() == 1 then
		local cur_pane_id = MuxUtil.get_current_pane_id()
		vim.fn.system("tmux split-window -h -p 20")
		M.back_to_pane(cur_pane_id)

		Config.settings.sendID = MuxUtil.get_id_next_pane()
	end

	if type(Config.settings.sendID) == "string" and #Config.settings.sendID == 0 then
		send_pane = MuxUtil.get_total_active_panes()
		Config.settings.sendID = MuxUtil.get_pane_id(send_pane)
	end

	if not MuxUtil.pane_exists(Config.settings.sendID) then
		Config.settings.sendID = MuxUtil.get_pane_id(MuxUtil.get_total_active_panes())
	end
end

local function __close_all()
	local total_panes = MuxUtil.get_total_active_panes()
	if current_pane_id ~= nil then
		current_pane_id = MuxUtil.get_current_pane_id()
	end

	if total_panes > 1 then
		for i = 1, total_panes do
			local pane_id = MuxUtil.get_pane_id(i)
			if current_pane_id ~= pane_id then
				vim.schedule(function()
					MuxUtil.kill_pane(pane_id)
				end)
			end
		end
	end
end

local function __get_config_state_cmd_pane(state_cmd)
	local _tbl = {}

	for _, panes in pairs(Config.settings.base.tbl_opened_panes) do
		if panes.state_cmd == state_cmd then
			_tbl = panes
		end
	end
	return _tbl
end

local function __insert_to_tbl_opened_panes(pane_id, pane_num, open_pane, state_cmd, command, regex)
	vim.validate({
		pane_id = { pane_id, "string", true },
		open_num = { pane_num, "string", true },
		open_pane = { open_pane, "string", true },
		state_cmd = { state_cmd, "string", true },
		command = { command, "string", true },
		-- NOTE:
		-- gimana cara nya membuat validate untuk 2 type (just like union)??
		-- karena 'regex' ini, type nya adalah "string " | "table"
		-- regex = { regex, "string", false },
	})
	return table.insert(Config.settings.base.tbl_opened_panes, {
		pane_id = pane_id,
		pane_num = pane_num,
		open_pane = open_pane,
		state_cmd = state_cmd,
		command = command,
		regex = regex,
	})
end

local function __update_item_tbl_opened_panes(fn)
	for idx, panes in pairs(Config.settings.base.tbl_opened_panes) do
		fn(idx, panes)
	end
end

function M.back_to_pane(cur_pane_id)
	vim.fn.system("tmux select-pane -t " .. cur_pane_id)
end

function M.back_to_pane_one()
	M.back_to_pane(current_pane_id)
end

function M.send(cmd, num_pane, isSendLine)
	isSendLine = isSendLine or false

	local tmux_cmd = tmux_send .. num_pane

	local visual_mode = false
	if type(cmd) == "table" then
		visual_mode = true
	end

	local cmd_nvim

	if visual_mode then
		Util.info({ msg = "Send range to pane " .. tostring(num_pane), setnotif = true })
		for _, cmdstr in pairs(cmd) do
			cmd_nvim = tmux_cmd .. " '" .. cmdstr .. "' Enter"
			vim.cmd("silent! " .. cmd_nvim)
		end
		return
	end

	local cwd = vim.fn.expand("%:p:h")
	local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")

	if isSendLine then
		cmd_nvim = tmux_cmd .. " '" .. cmd .. "' Enter"
	else
		cmd_nvim = tmux_cmd .. " '" .. cmd .. " " .. cwd .. "/" .. fname .. "'" .. " Enter"
	end

	vim.cmd("silent! " .. cmd_nvim)
end

function M.send_interrupt(send_all)
	send_all = send_all or false
	if send_all then
		if Config.settings.base.tbl_opened_panes and #Config.settings.base.tbl_opened_panes > 0 then
			for _, panes in pairs(Config.settings.base.tbl_opened_panes) do
				vim.fn.system(tmux_send .. panes.pane_id .. " '" .. MuxUtil.sendCtrlC() .. "' Enter")
			end
		end
	else
		if MuxUtil.get_total_active_panes() > 1 then
			vim.fn.system(tmux_send .. Config.settings.sendID .. " '" .. MuxUtil.sendCtrlC() .. "' Enter")
		end
	end
end

function M.close_all_task_panes()
	local tot_panes = Config.settings.base.tbl_opened_panes
	if #tot_panes > 0 then
		for _, pane in pairs(tot_panes) do
			vim.schedule(function()
				MuxUtil.kill_pane(pane.pane_id)
			end)
		end
	end

	__close_all()
end

function M.close_all_panes()
	current_pane_id = MuxUtil.get_current_pane_id()

	__close_all()

	Config.settings.base.tbl_opened_panes = {}
	M.back_to_pane(current_pane_id)
end

function M.send_runfile(opts, state_cmd)
	-- `true` paksa spawn 1 pane, jika terdapat hanya satu pane saja yang active
	local open_pane
	__respawn_pane(2)

	if MuxUtil.pane_iszoom() then
		MuxUtil.pane_toggle_zoom()
	end

	if not MuxUtil.pane_exists(Config.settings.sendID) then
		Config.settings.sendID = MuxUtil.get_pane_id(MuxUtil.get_total_active_panes())
	end

	-- Check if `pane_target.pane_id` is not exists, we must update the `pane_target.pane_id`
	local pane_target = __get_config_state_cmd_pane(state_cmd)
	if pane_target.state_cmd ~= Config.settings.provider_cmd.RUN_FILE then
		local pane_id = MuxUtil.get_pane_id(Config.settings.sendID)
		local pane_num = MuxUtil.get_pane_num(Config.settings.sendID)

		if MuxUtil.pane_exists(pane_id) then
			__insert_to_tbl_opened_panes(pane_id, pane_num, open_pane, state_cmd, opts.command, opts.regex)
		end
	else
		local pane_id = MuxUtil.get_pane_id(Config.settings.sendID)
		if MuxUtil.pane_exists(pane_id) then
			for _, pane in pairs(Config.settings.base.tbl_opened_panes) do
				pane.pane_id = pane_id
			end
		end
	end

	__update_item_tbl_opened_panes(function(_, panes)
		local pane_targetc = __get_config_state_cmd_pane(state_cmd)
		if opts.command ~= pane_targetc.command then
			if panes.state_cmd == pane_targetc.state_cmd then
				panes.command = opts.command
			end
		end
		if opts.regex ~= pane_targetc.regex then
			if panes.state_cmd == pane_targetc.state_cmd then
				panes.regex = opts.regex
			end
		end
		if opts.include_cwd ~= pane_targetc.include_cwd then
			if panes.state_cmd == pane_targetc.state_cmd then
				panes.include_cwd = opts.include_cwd
			end
		end
	end)

	-- After the pane_id
	-- now we send the commands to the correct pane target
	local pane_targetc = __get_config_state_cmd_pane(state_cmd)
	local tmux_sendcmd = tmux_send .. pane_targetc.pane_id
	local cmd_nvim = tmux_sendcmd .. " '" .. pane_targetc.command .. "'" .. " Enter"

	if opts.include_cwd then
		local cwd = vim.fn.expand("%:p:h")
		local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")

		cmd_nvim = tmux_sendcmd .. " '" .. pane_targetc.command .. " " .. cwd .. "/" .. fname .. "'" .. " Enter"
	end

	vim.fn.system(cmd_nvim)
end

function M.send_line(send_pane)
	__respawn_pane(send_pane)

	local linenr = vim.api.nvim_win_get_cursor(0)[1]
	vim.cmd("silent! " .. linenr .. "," .. linenr .. " :w  !tmux load-buffer -")
	vim.fn.system("tmux paste-buffer -dpr -t " .. send_pane)
end

function M.send_visual(send_pane)
	__respawn_pane(send_pane)

	if MuxUtil.pane_iszoom() then
		MuxUtil.pane_toggle_zoom()
	end

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

	vim.cmd("silent " .. b_line .. "," .. e_line .. ":w  !tmux load-buffer -")

	vim.fn.system("tmux paste-buffer -dpr -t " .. send_pane)
end

local status_pane_repl = false
function M.openREPL(langs_opts)
	if status_pane_repl then
		if MuxUtil.pane_exists(Config.settings.sendID) then
			status_pane_repl = false
		end
	end

	if not status_pane_repl then
		__respawn_pane(1)

		local tmux_cmd = tmux_send .. Config.settings.sendID
		local cmd_nvim = tmux_cmd .. " '" .. langs_opts.command .. "'" .. " Enter"
		vim.fn.system(cmd_nvim)
		status_pane_repl = true
	end
end

function M.open_multi_panes(layouts, state_cmd)
	current_pane_id = MuxUtil.get_current_pane_id()

	for idx, layout in pairs(layouts) do
		if layout.open_pane ~= nil and #layout.open_pane > 0 then
			local layouts_idx = layouts[idx]
			-- `pane_id` is the command for create, open dan get the id of pane nya langsung
			local pane_id =
				MuxUtil.normalize_return(vim.fn.system(layout.open_pane .. '\\; display-message -p "#{pane_id}"'))
			local pane_num = MuxUtil.get_pane_num(pane_id)

			__insert_to_tbl_opened_panes(
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
end

function M.send_multi(state_cmd)
	for _, panes in pairs(Config.settings.base.tbl_opened_panes) do
		if panes.state_cmd == state_cmd then
			-- vim.fn.system(tmux_send .. panes.pane_id .. " '" .. panes.command .. "' " .. "Enter \\; last-pane")
			vim.fn.system(tmux_send .. panes.pane_id .. " '" .. panes.command .. "' " .. "Enter")
		end
	end

	if type(Config.settings.sendID) == "string" and #Config.settings.sendID == 0 then
		Config.settings.sendID = MuxUtil.get_pane_id(MuxUtil.get_total_active_panes())
	end
end

function M.grep_string_pane(send_pane)
	__respawn_pane(send_pane)

	if #Config.settings.base.tbl_opened_panes == 0 then
		return print("No active")
	end

	local target_pane_num = MuxUtil.get_pane_num(Config.settings.sendID)
	local target_pane_id = Config.settings.sendID

	local pane_target
	for _, panes in pairs(Config.settings.base.tbl_opened_panes) do
		if panes.pane_id == target_pane_id then
			-- print(panes.pane_id)
			pane_target = panes
			-- if found_pane_id == nil then
			-- if #panes.regex == 0 then
			-- if panes.state_cmd == Config.settings.provider_cmd.RUN_FILE then
			-- 	found_pane_id = true
			-- 	pane_regex = panes.regex
			-- end
			-- else
			-- 	found_pane_id = true
			-- 	pane_regex = panes.regex
			-- end
			-- end
		end
	end

	if pane_target then
		vim.schedule(function()
			local output = {}
			local cmd = MuxUtil.pane_capture(target_pane_num, pane_target.regex)
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
				Fzf.grep_err(output, MuxUtil.get_pane_num(pane_target.pane_id))
			end
		end)
	end
end

return M
