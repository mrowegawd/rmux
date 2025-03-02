local Constant = require("rmux.constant")
-- local Path = require("plenary.path")
local Util = require("rmux.utils")

local Config = require("rmux.config")

local WezUtil = require("rmux.integrations.wez.util")

local M = {}

local wezterm_send = "wezterm cli "

local current_pane_id

local size_pane = 35

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
				opts.command
				-- opts.regex
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
-- Di wez harus merujuk `--pane-id` nya, jadi harus ditulis seperti ini:
-- wezterm cli split-pane --bottom --percent 40 --pane-id (last-id)
-- wezterm cli split-pane --right --percent 80 --pane-id (last-id)
-- wezterm cli split-pane --right --percent 70 --pane-id (last-id)
-- wezterm cli split-pane --right --percent 60 --pane-id (last-id)

function M.get_current_pane_id()
	local id = vim.env.WEZTERM_PANE
	if id then
		id = id:gsub("^%s+", ""):gsub("%s+$", "")
		return id
	end
end

local function __list_panes()
	return Util.jsonDecode(Util.normalize_return(vim.fn.system("wezterm cli list --format json")))
end

local function __list_tabs()
	local by_id = {}
	local tabs = {}
	local panes = __list_panes()
	if not panes then
		return
	end
	for _, pane in ipairs(panes) do
		local tab_id = pane.tab_id
		if not by_id[tab_id] then
			by_id[tab_id] = {
				tab_id = tab_id,
				tab_title = pane.tab_title,
				window_id = pane.window_id,
				window_title = pane.window_title,
				panes = {},
			}
			table.insert(tabs, by_id[tab_id])
		end
		table.insert(by_id[tab_id].panes, pane)
	end

	return tabs
end

local function __get_list_panes(call_again)
	local list_json_tbl
	call_again = call_again or false
	if list_json_tbl == nil or call_again then
		list_json_tbl = __list_panes()
	end

	return list_json_tbl
end

function M.get_total_active_panes()
	local current_pane = M.get_current_pane_id()

	local tabs = __list_tabs()
	if tabs == nil then
		return 1
	end

	local tbl = {}
	for _, t in pairs(tabs) do
		if #t.panes > 0 then
			for _, p in pairs(t.panes) do
				if p.pane_id == tonumber(current_pane) then
					tbl = t.panes
				end
			end
		end
	end

	return #tbl
end

-- Get a list of pane IDs only; { 1, 2, 3 }
function M.get_lists_pane_id_opened()
	local current_pane = M.get_current_pane_id()

	local tabs = __list_tabs()
	if tabs == nil then
		return {}
	end

	local panes = {}
	for _, t in pairs(tabs) do
		if #t.panes > 0 then
			for _, p in pairs(t.panes) do
				if p.pane_id == tonumber(current_pane) then
					panes = t.panes
				end
			end
		end
	end

	local list_pane_ids = {}
	for _, x in pairs(panes) do
		list_pane_ids[#list_pane_ids + 1] = tostring(x.pane_id)
	end

	return list_pane_ids
end

function M.get_pane_idx(pane_id)
	vim.validate({ pane_id = { pane_id, "string" } })

	local idx = 1
	local tabs = __list_tabs()
	if tabs == nil then
		return idx
	end

	for _, t in pairs(tabs) do
		if #t.panes > 0 then
			for _, p in pairs(t.panes) do
				if p.pane_id == tonumber(pane_id) then
					idx = p.window_id
					break
				end
			end
		end
	end
	return idx
end

function M.pane_exists(pane_id)
	-- print(vim.inspect(__list_panes()))
	-- for _, x in pairs(__list_panes()) do
	-- 	if x.pane_id == pane_id then
	-- 		return true
	-- 	end
	-- end
	-- return false

	return true
end

function M.send_clear_screen(pane_id)
	vim.fn.system("wezterm cli send-text --no-paste " .. M.__pressing_clear() .. " --pane-id " .. pane_id)
end

function M.send_enter(pane_id)
	vim.fn.system("wezterm cli send-text --no-paste " .. M.__pressing_enter() .. " --pane-id " .. pane_id)
end

function M.__pressing_enter()
	return "$'\r'"
end

function M.__pressing_ctrlc()
	return "^C"
end

function M.__pressing_clear()
	return "$'clear'"
end

function M.jump_to_pane_id(pane_id)
	vim.fn.system("wezterm cli activate-pane --pane-id " .. pane_id)
end

function M.send_pane_cmd(task, isnewline)
	vim.validate({
		task = { task, "table", true },
		isnewline = { isnewline, "boolean", true },
	})

	-- ensure cmd is not empty
	if #task.builder.cmd == 0 then
		return
	end

	local pane_id = task.pane_id
	local cmd_msg = task.builder.cmd

	if not M.pane_exists(pane_id) then
		Util.warn({ msg = pane_id .. " pane not exist" })
		return
	end

	if isnewline then
		M.send_clear_screen(pane_id)
		M.send_enter(pane_id)
	end

	local wezterm_send_cmd = "wezterm cli send-text --no-paste '" .. cmd_msg .. "' --pane-id " .. pane_id
	vim.fn.system(wezterm_send_cmd)
	M.send_enter(pane_id)
end

function M.is_pane_at_bottom()
	local is_bottom = Util.normalize_return(vim.fn.system("wezterm cli get-pane-direction down"))
	if is_bottom and (#is_bottom == 0) then
		return true
	end
	return false
end

function M.create_new_pane(cwd, expand_pane)
	expand_pane = expand_pane or false
	cwd = cwd or vim.fn.getcwd()

	local pane_id
	if M.is_pane_at_bottom() and not expand_pane then
		pane_id = Util.normalize_return(
			vim.fn.system("wezterm cli split-pane --bottom --percent " .. size_pane .. " --cwd " .. cwd)
		)
	end

	-- Membuat layout pada wezterm agak berbeda dengan tmux, jika ingin membuat
	-- layout (horizontal/vertical) berdasarkan pane yang baru saja dibuat maka
	-- kita harus mendapatkan pane_id dari pane baru itu, lalu men-define
	-- --pane-id untuk create split horizontal/vertical berdasarkan pane-id
	-- mereka. Seperti ini contoh: "wezterm cli split-pane --horizontal --pane-id <pane_id>"
	--
	-- Untuk itu `get_direction_pane_id` ini diperlukan untuk mengatasi hal tersebut
	local get_direction_pane_id
	if expand_pane then
		if not M.is_pane_at_bottom() then
			get_direction_pane_id = Util.normalize_return(vim.fn.system("wezterm cli get-pane-direction down"))
		end

		if get_direction_pane_id then
			pane_id = Util.normalize_return(
				vim.fn.system(
					"wezterm cli split-pane --horizontal --pane-id " .. get_direction_pane_id .. " --cwd " .. cwd
				)
			)
		else
			pane_id = Util.normalize_return(vim.fn.system("wezterm cli split-pane --horizontal --cwd " .. cwd))
		end
	end

	vim.uv.sleep(50)

	if pane_id then
		Constant.set_sendID(tostring(pane_id))
	end
end

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
				layouts_idx.command
				-- layouts_idx.regex
			)
		else
			Util.warn({ msg = "Why did this happen?\n- There is no file .rmuxrc.json", setnotif = true })
		end
	end

	M.send_multi(state_cmd)
	M.back_to_pane_one()
end

function M.open_vertical_pane(pane_strategy, size)
	size = size or size_pane
	vim.validate({
		pane_strategy = { pane_strategy, "string" },
		size = { size, "number" },
	})

	local wez_split_cmd = "wezterm cli split-pane --bottom --percent " .. size_pane + 20
	if pane_strategy == "-h" then
		wez_split_cmd = "wezterm cli split-pane --right"
	end

	local pane_id
	if pane_strategy == "-v" then
		pane_id = Util.normalize_return(vim.fn.system(wez_split_cmd))
		Constant.set_sendID(pane_id)
	elseif pane_strategy == "-h" then
		local set_pane_id = Constant.get_sendID()
		pane_id = Util.normalize_return(vim.fn.system(wez_split_cmd .. " --pane-id " .. set_pane_id))
		Constant.set_sendID(pane_id)
	end

	return tostring(pane_id)
end

function M.reset_resize_pane(pane_id)
	pane_id = pane_id or ""
	return true
end

function M.kill_pane(pane_id)
	if M.pane_exists(pane_id) then
		return vim.fn.system("wezterm cli kill-pane --pane-id " .. pane_id)
	end
end

function M.get_pane_width()
	return Util.normalize_return(vim.fn.system("tput cols"))
end

function M.back_to_pane_one()
	if current_pane_id then
		WezUtil.back_to_pane(current_pane_id)
	end
end

-- TODO: belum tau cara capture di wezterm
function M.cmd_str_capture_pane(pane_id, num_history_lines)
	num_history_lines = num_history_lines or 10000

	vim.validate({ pane_id = { pane_id, "string" }, num_history_lines = { num_history_lines, "number" } })

	local tabs = __list_tabs()
	if tabs == nil then
		return 1
	end

	for _, t in pairs(tabs) do
		if #t.panes > 0 then
			for _, p in pairs(t.panes) do
				if p.pane_id == tonumber(pane_id) then
					num_history_lines = p.size.pixel_height
				end
			end
		end
	end

	return { "wezterm", "cli", "get-text", "--start-line", num_history_lines, "--end-line", "0", "--pane-id", pane_id }
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

-- TODO: ini belum selesai
function M.grep_err_output_commands(current_pane, target_panes, opts)
	vim.validate({
		current_pane = { current_pane, "string" },
		target_panes = { target_panes, "table" },
		opts = { opts, "table" },
	})

	-- local target_pane_num = WezUtil.get_pane_num(Config.settings.sendID)
	-- local target_pane_id = Config.settings.sendID
	--
	-- local pane_target
	-- for _, panes in pairs(Constant.get_tbl_opened_panes()) do
	-- 	if panes.pane_id == target_pane_id then
	-- 		pane_target = panes
	-- 	end
	-- end
	--
	-- if pane_target then
	-- 	vim.schedule(function()
	-- 		local output = {}
	-- 		local cmd = WezUtil.pane_capture(target_pane_num, pane_target.regex)
	-- 		if cmd.output ~= nil then
	-- 			local res = vim.split(cmd.output, "\n")
	-- 			for index = 2, #res - 1 do
	-- 				local item = res[index]
	-- 				if item ~= "" then
	-- 					table.insert(output, item)
	-- 				end
	-- 			end
	-- 		end
	--
	-- 		if #output > 0 then
	-- 			Fzf.grep_err(output, WezUtil.get_pane_num(pane_target.pane_id))
	-- 		end
	-- 	end)
	-- end

	local panes = target_panes
	local grep_cmd = opts.grep_cmd
	local regex = opts.regex

	local num_history_lines = opts.num_history_lines or 10000

	local results = {}

	for _, pane in ipairs(panes) do
		local pane_id = pane
		if pane_id ~= current_pane then
			print(pane_id)
			-- local pane_path = Util.get_os_command_output({
			-- 	"tmux",
			-- 	"display",
			-- 	"-pt",
			-- 	pane_id,
			-- 	"#{pane_current_path}",
			-- })[1] or ""
			-- 	local command_str = "tmux capture-pane -p -t "
			-- 		.. pane_id
			-- 		.. " -S "
			-- 		.. -num_history_lines
			-- 		.. " | "
			-- 		.. grep_cmd
			-- 		.. " '"
			-- 		.. regex
			-- 		.. "' | tr -d ' '"
			-- 	local contents = Util.get_os_command_output({
			-- 		"sh",
			-- 		"-c",
			-- 		command_str,
			-- 	})
			-- 	if contents then
			-- 		for _, line in ipairs(contents) do
			-- 			-- parse path, line, col
			-- 			local splits = {}
			-- 			local i = 1
			-- 			for part in string.gmatch(line, "[^:]+") do
			-- 				splits[i] = part
			-- 				i = i + 1
			-- 			end
			-- 			local path = Path:new(splits[1])
			-- 			if not path:is_absolute() then
			-- 				path = Path:new(pane_path, path)
			-- 			end
			-- 			if path:is_file() then
			-- 				local result = { path = path:normalize(), lnum = splits[2], cnum = splits[3] }
			-- 				local key = result.path .. ":" .. (result.lnum or "") .. ":" .. (result.cnum or "")
			-- 				if results[key] == nil then
			-- 					results[key] = result
			-- 				end
			-- 			end
			-- 		end
			-- 	end
		end
	end

	return results
end

return M
