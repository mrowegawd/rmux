local Constant = require("rmux.constant")
local Path = require("plenary.path")
local Util = require("rmux.utils")

local size_pane = Constant.get_size_pane()

-- function get_last_active_pane()
-- 	return M.send_cmd_with_return("tmux list-panes | tail -1 | cut -d':' -f1")
-- end

-- function pane_capture(pane_num, grep_cmd)
-- 	local cmd = [[!tmux capture-pane -pJS - -t ]] .. pane_num .. " | sort -r | grep -oiE '" .. grep_cmd .. "' | tac"
-- 	return vim.api.nvim_exec2(cmd, { output = true })
-- end

local function __cmd_ctrl_c()
	return "^C"
end

local function __cmd_clear_screen()
	return "clear"
end

local M = {}

function M.is_pane_zoomed()
	local is_zoom = M.send_cmd_with_return([[tmux display-message -p "#F]])
	if is_zoom == "*Z" then
		return true
	end
	return false
end

function M.is_pane_at_bottom()
	-- outout 1 or 0, 1 -> yes, pane at bottom
	local bottom = M.send_cmd_with_return("tmux display -p '#{pane_at_bottom}'")
	if tonumber(bottom) == 1 then
		return true
	end
	return false
end

function M.is_current_pane_program_name(program_name)
	vim.validate({ msg = { program_name, "string" } })

	local program_pane_name = M.get_pane_current_command(M.get_pane_idx_from_id(M.get_current_pane_id()))
	if program_pane_name == program_name then
		return true
	end

	return false
end

function M.set_pane_zoom()
	M.send_cmd_wrapper("tmux resize-pane -Z", true)
end

function M.reset_size_pane()
	M.send_cmd_wrapper([[tmux select-layout -E]], true)
end

function M.cmd_str_capture_pane(pane_id, num_history_lines)
	num_history_lines = num_history_lines or 10000
	vim.validate({ pane_id = { pane_id, "string" }, num_history_lines = { num_history_lines, "number" } })
	return { "tmux", "capture-pane", "-p", "-t", pane_id, "-S", -num_history_lines, "-e" }
end

function M.is_pane_exists(pane_id)
	vim.validate({ pane_id = { pane_id, "string" } })
	local result = M.send_cmd_with_return("tmux display -t " .. pane_id .. " -p '#{pane_id}'")
	result = result:gsub("\n", "")

	if #result > 0 then
		return true
	end
	return false
end

function M.get_current_pane_id()
	local pane_id = M.send_cmd_with_return("tmux display -p '#{pane_id}'")
	return pane_id:gsub("\n", "")
end

function M.get_pane_id_from_idx(pane_idx)
	vim.validate({ pane_idx = { tonumber(pane_idx), "number" } })

	local pane_id = M.send_cmd_with_return("tmux display -t " .. pane_idx .. " -p '#{pane_id}'")
	return pane_id:gsub("\n", "")
end

function M.get_pane_idx_from_id(pane_id)
	vim.validate({ pane_id = { pane_id, "string" } })
	local pane_idx = M.send_cmd_with_return("tmux display-message -t " .. pane_id .. " -p '#{pane_index}'")
	pane_idx = pane_idx:gsub("\n", "")
	return tonumber(pane_idx)
end

function M.get_pane_width()
	return M.send_cmd_with_return("tput cols")
end

function M.get_pane_height()
	return M.send_cmd_with_return("tput lines")
end

function M.get_pane_current_command(pane_idx)
	vim.validate({ pane_idx = { tonumber(pane_idx), "number" } })
	local program_name =
		M.send_cmd_with_return("tmux display-message -p -t " .. pane_idx .. " '#{pane_current_command}'")
	return program_name:gsub("\n", "")
end

function M.get_total_active_panes()
	local total_active_panes = M.send_cmd_with_return("tmux list-panes | wc -l")
	if type(total_active_panes) == "string" then
		return tonumber(total_active_panes)
	end
end

function M.get_lists_pane_id_opened()
	-- Get a list of pane IDs only; { 1, 2, 3 }
	local tbl_pane_idx = {}
	for pane_idx = 1, M.get_total_active_panes() do
		tbl_pane_idx[#tbl_pane_idx + 1] = M.get_pane_id_from_idx(pane_idx)
	end
	return tbl_pane_idx
end

function M.create_new_pane(cwd, expand_pane)
	expand_pane = expand_pane or false
	cwd = cwd or vim.fn.getcwd()

	local pane_id
	local mode_open
	local set_expand = false
	if M.is_pane_at_bottom() and not expand_pane then
		mode_open = "-vl"
	end

	if expand_pane then
		if M.is_pane_at_bottom() then
			mode_open = "-vl"
		else
			M.jump_to_last_pane()
			if M.is_current_pane_program_name("yazi") then
				M.jump_to_last_pane()
				M.go_down_pane()
			end
			mode_open = "-hl"
			set_expand = true
		end
	end

	M.send_cmd_wrapper("tmux split-window " .. mode_open .. " " .. size_pane .. " -c " .. cwd, true)
	pane_id = M.get_current_pane_id()

	if M.is_pane_at_bottom() and set_expand then
		M.reset_size_pane()
	end

	if pane_id then
		Constant.set_sendID(pane_id)
	end
end

function M.update_keys_task(task_tbl_panes, lang_task)
	task_tbl_panes.builder = lang_task.builder({})
	task_tbl_panes.name = lang_task.name
	local pane_id = Constant.get_sendID()
	task_tbl_panes.pane_id = pane_id
	Constant.set_sendID(pane_id)

	if not M.is_pane_exists(task_tbl_panes.pane_id) then
		M.go_right_pane()
		task_tbl_panes.pane_id = pane_id
	end
	M.go_left_pane()
end

function M.open_vertical_pane(pane_strategy, size)
	vim.validate({
		pane_strategy = { pane_strategy, "string" },
		size = { size, "number" },
	})

	local tmux_split_cmd = "tmux split-window " .. pane_strategy .. " -l " .. tostring(size)
	if pane_strategy == "-h" then
		tmux_split_cmd = "tmux split-window " .. pane_strategy
	end

	M.send_cmd_wrapper(tmux_split_cmd, true)

	local pane_id = M.get_current_pane_id()
	return pane_id
end

function M.grep_err_output_commands(current_pane, target_pane, opts)
	vim.validate({
		current_pane = { current_pane, "string" },
		target_panes = { target_pane, "string" },
		opts = { opts, "table" },
	})

	local pane_id = target_pane
	local grep_cmd = opts.grep_cmd
	local regex = opts.regex
	local num_history_lines = opts.num_history_lines or 10000

	local results = {}
	local seen = {}

	if pane_id == current_pane then
		Util.error("Grep err output cancelled: active pane does not match the expected pane")
		return
	end

	local pane_path = Util.get_os_command_output({
		"tmux",
		"display",
		"-pt",
		pane_id,
		"#{pane_current_path}",
	})[1] or ""

	local parse

	local command_str = "tmux capture-pane -p -t " .. pane_id .. " -S " .. -num_history_lines

	if type(regex) == "string" then
		command_str = command_str .. " | " .. grep_cmd .. " '" .. regex .. "' | tr -d ' '"
	end

	if type(regex) == "table" then
		local Parser = require("overseer.parser")
		parse = Parser.new(regex)
	end

	local contents = Util.get_os_command_output({
		"sh",
		"-c",
		command_str,
	})

	if not contents or (contents and #contents == 0) then
		Util.error("Grep err output cancelled: contents are empty or undefined")
		return
	end

	local lnum, cnum, pathx, text

	for _, line in ipairs(contents) do
		if type(regex) == "table" then
			parse:ingest({ line })
			local get_result = parse:get_result()
			for _, res in pairs(get_result) do
				pathx = res.filename
				lnum = res.lnum or 0
				cnum = res.col or 0
				text = res.text
			end
		else
			local splits = {}
			local i = 1
			for part in string.gmatch(line, "[^:]+") do
				splits[i] = part
				i = i + 1
			end

			pathx = splits[1]
			lnum = splits[2]
			cnum = splits[3]
		end

		local path = Path:new(pathx)

		if not path:is_absolute() then
			path = Path:new(pane_path, path)
		end

		if path:is_file() then
			local result = { path = path:normalize(), lnum = lnum, cnum = cnum, text = text }
			local key = result.path .. ":" .. (result.lnum or "") .. ":" .. (result.cnum or "")
			if not seen[key] then
				table.insert(results, result)
				seen[key] = true
			end
		end
	end

	return results
end

function M.fzf_select_panes(is_watcher)
	is_watcher = is_watcher or false

	local pane_lists = M.get_lists_pane_id_opened()
	local cur_pane_id = M.get_current_pane_id()

	if pane_lists and #pane_lists == 1 then
		Util.warn("Only one pane is open. No action taken")
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
	local tbl_active_tasks = Constant.get_active_tasks()
	for _, p_id in pairs(pane_opened) do
		for _, task in pairs(tbl_active_tasks) do
			if task.pane_id == p_id then
				tbl_taks_pane_opened[p_id] = {
					pane_id = task.pane_id,
					pane_idx = task.pane_idx,
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

	-- Tasks in the select pane should follow tmux's index
	local function format_results()
		local temp = {}
		for k, v in pairs(opts.results) do
			if type(v) == "table" and v.builder ~= nil then
				table.insert(temp, { name = k, pane_idx = v.pane_idx, cmd = v.builder.name })
			else
				table.insert(temp, { name = k, pane_idx = v.pane_idx, cmd = "" })
			end
		end

		table.sort(temp, function(a, b)
			return a.pane_idx < b.pane_idx
		end)

		local items = {}
		for _, res in pairs(temp) do
			items[#items + 1] = res.name .. "  " .. res.cmd
		end

		return items
	end

	opts.select_pane_fzf = format_results()

	return opts
end

-- ╭─────────────────────────────────────────────────────────╮
-- │                          SEND                           │
-- ╰─────────────────────────────────────────────────────────╯

function M.send(contents, is_cmd_only, target_pane, is_clear_sceen)
	vim.validate({ target_pane = { target_pane, "string" } })
	is_cmd_only = is_cmd_only or false

	local split_content
	local cmds

	if is_cmd_only then
		cmds = contents
	end

	if not is_cmd_only then
		if type(contents) == "table" then
			split_content = Util.list_strip_empty_lines(contents)
			cmds = "echo '" .. table.concat(split_content, "\n") .. "' | tmux load-buffer -"
		end

		if type(contents) == "string" then
			split_content = contents
			cmds = "echo '" .. split_content .. "' | tmux load-buffer -"
		end

		-- Tmux may not update the buffer with an empty string.
		if split_content and #split_content == 0 then
			cmds = "echo '\n' | tmux load-buffer -"
		end
	end

	if is_clear_sceen then
		local cmd_newline = [[tmux send -t ]] .. target_pane .. [[ "]] .. __cmd_clear_screen() .. [[" Enter]]
		Util.system_call_prefix(cmd_newline)
	end

	local stdout = Util.system_call_prefix(cmds)

	if not is_cmd_only then
		Util.system_call_prefix("tmux paste-buffer -dpr -t " .. target_pane)
	end

	return stdout
end

function M.send_cmd_with_return(contents)
	vim.validate({ contents = { contents, "string" } })
	return M.send(contents, true, "")
end

function M.send_cmd_wrapper(contents, is_send_cmd, target_pane, is_clear_screen)
	is_send_cmd = is_send_cmd or false
	target_pane = target_pane or ""
	is_clear_screen = is_clear_screen or false

	local tmux_cmds
	if #target_pane > 0 then
		if not M.is_pane_exists(target_pane) then
			Util.warn("The pane '" .. target_pane .. "' is no longer exists or has been deleted")
			return
		end

		if is_send_cmd then
			local send_to_pane = "tmux send -t " .. target_pane
			tmux_cmds = send_to_pane .. " '" .. contents .. "'" .. " Enter"
		else
			tmux_cmds = contents
		end
	else
		tmux_cmds = contents
	end

	M.send(tmux_cmds, is_send_cmd, target_pane, is_clear_screen)
end

function M.send_pane_cmd_task(task, is_clear_screen)
	if #task.builder.cmd == 0 then
		Util.warn("Task cmd is empty!")
		return
	end

	local target_pane = task.pane_id
	local contents = task.builder.cmd

	M.send_cmd_wrapper(contents, true, target_pane, is_clear_screen)
end

function M.send_interrupt(target_pane)
	local send_pane = Constant.get_sendID()
	target_pane = target_pane or send_pane

	M.send_cmd_wrapper(__cmd_ctrl_c(), true, target_pane)
end

function M.send_line(target_pane)
	local send_pane = Constant.get_sendID()
	target_pane = target_pane or send_pane

	local line = vim.api.nvim_get_current_line()
	M.send_cmd_wrapper(line, false, target_pane)
end

local str_widthindex = function(s, index)
	if index < 1 or #s < index then
		-- return full range if index is out of range
		return { 1, vim.api.nvim_strwidth(s) }
	end

	local ws, we, b = 0, 0, 1
	while b <= #s and b <= index do
		local ch = s:sub(b, b + vim.str_utf_end(s, b))
		local wch = vim.api.nvim_strwidth(ch)
		ws = we + 1
		we = ws + wch - 1
		b = b + vim.str_utf_end(s, b) + 1
	end

	return { ws, we }
end

local str_wbyteindex = function(s, index)
	if index < 1 or vim.api.nvim_strwidth(s) < index then
		-- return full range if index is out of range
		return { 1, #s }
	end

	local b, bs, be, w = 1, 0, 0, 0
	while b <= #s and w < index do
		bs = b
		be = bs + vim.str_utf_end(s, bs)
		local ch = s:sub(bs, be)
		local wch = vim.api.nvim_strwidth(ch)
		w = w + wch
		b = be + 1
	end

	return { bs, be }
end

function M.send_range_line(target_pane)
	local send_pane = Constant.get_sendID()
	target_pane = target_pane or send_pane

	local c_v = vim.api.nvim_replace_termcodes("<C-v>", true, true, true)
	local modes = { "v", "V", c_v }
	local mode = vim.fn.mode():sub(1, 1)
	if not vim.tbl_contains(modes, mode) then
		return {}
	end

	-- Get the start and end positions of the selection
	local _, ls, cs = unpack(vim.fn.getpos("v"))
	local _, le, ce = unpack(vim.fn.getpos("."))

	-- Ensure start position is before end position
	if ls > le or (ls == le and cs > ce) then
		ls, le = le, ls
		cs, ce = ce, cs
	end

	-- Get the lines in the selection
	local lines = vim.api.nvim_buf_get_lines(0, ls - 1, le, false)
	if #lines == 0 then
		return {}
	end
	ce = math.min(ce, #lines[#lines])

	if mode == "v" or mode == "V" then
		if mode == "v" then
			if #lines == 1 then
				return { string.sub(lines[1], cs, ce) }
			end
			lines[1] = string.sub(lines[1], cs)
			lines[#lines] = string.sub(lines[#lines], 1, ce)
		end
	else
		--  TODO: visual block: fix weird behavior when selection include end of line
		local csw = math.min(str_widthindex(lines[1], cs)[1], str_widthindex(lines[#lines], ce)[1])
		local cew = math.max(str_widthindex(lines[1], cs)[2], str_widthindex(lines[#lines], ce)[2])
		for i, line in ipairs(lines) do
			-- byte index for current line from width index
			local csl = str_wbyteindex(line, csw)[1]
			local cel = str_wbyteindex(line, cew)[2]
			lines[i] = string.sub(line, csl, cel)
		end
	end

	M.send_cmd_wrapper(lines, false, target_pane)
end

-- ╭─────────────────────────────────────────────────────────╮
-- │                        NAVIGATE                         │
-- ╰─────────────────────────────────────────────────────────╯

function M.kill_pane(pane_id)
	if M.is_pane_exists(pane_id) then
		M.send_cmd_wrapper("tmux kill-pane -t " .. pane_id, true)
	end
end

function M.jump_to_pane_id(pane_id)
	vim.validate({ pane_id = { pane_id, "string" } })
	M.send_cmd_wrapper("tmux select-pane -t " .. pane_id, true)
end

function M.jump_to_last_pane()
	M.send_cmd_wrapper("tmux last-pane", true)
end

function M.go_right_pane()
	M.send_cmd_wrapper("tmux select-pane -R", true)
end

function M.go_left_pane()
	M.send_cmd_wrapper("tmux select-pane -L", true)
end

function M.go_down_pane()
	M.send_cmd_wrapper("tmux select-pane -D", true)
end

return M
