local Constant = require("rmux.constant")
local Path = require("plenary.path")
local Util = require("rmux.utils")

local size_pane = Constant.get_size_pane()

local function __cmd_ctrl_c()
	return "^C"
end

local function __cmd_clear_screen()
	return "clear"
end

local M = {}

function M.pane_iszoom()
	return Util.normalize_return(vim.fn.system([[tmux display-message -p "#F"]])) == "*Z"
end

function M.pane_toggle_zoom()
	return Util.normalize_return(vim.fn.system([[tmux resize-pane -Z]]))
end

function M.reset_resize_pane(pane_id)
	pane_id = pane_id or ""
	return Util.normalize_return(vim.fn.system([[tmux select-layout -E]]))
end

-- function M.pane_capture(pane_num, grep_cmd)
-- 	local cmd = [[!tmux capture-pane -pJS - -t ]] .. pane_num .. " | sort -r | grep -oiE '" .. grep_cmd .. "' | tac"
-- 	return vim.api.nvim_exec2(cmd, { output = true })
-- end

function M.cmd_str_capture_pane(pane_id, num_history_lines)
	num_history_lines = num_history_lines or 10000
	vim.validate({ pane_id = { pane_id, "string" }, num_history_lines = { num_history_lines, "number" } })
	return { "tmux", "capture-pane", "-p", "-t", pane_id, "-S", -num_history_lines, "-e" }
end

function M.is_pane_exists(pane_id)
	vim.validate({ pane_id = { pane_id, "string" } })
	local result = (Util.normalize_return(vim.fn.system("tmux display -t " .. pane_id .. " -p '#{pane_id}'")) == "")
	if type(result) == "boolean" and not result then
		return true
	end
	return false
end

function M.get_pane_id(pane_idx)
	vim.validate({ pane_idx = { tonumber(pane_idx), "number" } })
	local pane_id = Util.normalize_return(vim.fn.system("tmux display -t " .. pane_idx .. " -p '#{pane_id}'"))

	if tostring(pane_id):match("%%") then
		return pane_id
	elseif #pane_id == 0 then
		Util.warn("pane_idx (index pane) is nil, its not active anymore")
		return
	else
		Util.warn("pane_id: " .. tostring(pane_id) .. " must contains with %")
		return
	end
end

function M.get_pane_idx(pane_id)
	vim.validate({ pane_id = { pane_id, "string" } })
	return Util.normalize_return(vim.fn.system("tmux display -t " .. pane_id .. " -p '#{pane_index}'"))
end

function M.get_pane_current_command(pane_idx)
	vim.validate({
		pane_idx = { tonumber(pane_idx), "number" },
	})
	return Util.normalize_return(
		vim.fn.system("tmux display-message -t " .. pane_idx .. " -p '#{pane_current_command}'")
	)
end

function M.get_total_active_panes()
	return tonumber(Util.normalize_return(vim.fn.system("tmux list-panes | wc -l")))
end

function M.get_lists_pane_id_opened()
	-- Get a list of pane IDs only; { 1, 2, 3 }
	local total_panes = {}
	for i = 1, M.get_total_active_panes() do
		total_panes[#total_panes + 1] = M.get_pane_id(i)
	end
	return total_panes
end

function M.get_last_active_pane()
	return Util.normalize_return(vim.fn.system("tmux list-panes | tail -1 | cut -d':' -f1"))
end

function M.get_current_pane_id()
	return Util.normalize_return(vim.fn.system([[tmux display -p '#{pane_id}']]))
end

function M.get_current_pane_idx()
	return Util.normalize_return(
		vim.fn.system([[tmux display -t ]] .. M.get_current_pane_id() .. [[ -p '#{pane_index}']])
	)
end

function M.get_id_next_pane()
	-- Jika terdapat 2 pane yang aktif, ambil 'the next' pane id number nya
	return Util.normalize_return(vim.fn.system("tmux list-panes | grep -v 'active' | cut -d' ' -f7 | head -n 1"))
end

function M.get_pane_target(pane_idx)
	vim.validate({ pane_idx = { tonumber(pane_idx), "number" } })
	return Util.normalize_return(vim.fn.system("tmux display-message -t " .. pane_idx .. ' -p "#{pane_id}"'))
end

function M.kill_pane(pane_id)
	if M.is_pane_exists(pane_id) then
		return vim.fn.system("tmux kill-pane -t " .. pane_id)
	end
end

function M.back_to_pane(pane_idx)
	vim.validate({ pane_idx = { pane_idx, "number" } })
	vim.fn.system("tmux select-pane -t " .. pane_idx)
end

function M.jump_to_pane_id(pane_id)
	vim.validate({ pane_idx = { pane_id, "string" } })
	vim.fn.system("tmux select-pane -t " .. pane_id)
end

function M.check_right_pane_current_command()
	M.go_right_pane()
	return Util.normalize_return(
		vim.fn.system([[tmux display -p "#{pane_id} #{pane_current_command}" | awk '$2 == "zsh" { print $2; exit }']])
	)
end

function M.check_current_program_pane_name(msg)
	vim.validate({ msg = { msg, "string" } })
	return Util.normalize_return(
		vim.fn.system(
			[[tmux display -p "#{pane_id} #{pane_current_command}" | awk '$2 == "]] .. msg .. [[" { print $2; exit }']]
		)
	)
end

function M.check_right_pane_id()
	M.go_right_pane()
	return Util.normalize_return(vim.fn.system([[tmux display -p "#{pane_id}"]]))
end

function M.is_pane_at_bottom()
	-- outout 1 or 0, 1 -> yes, pane at bottom
	if tonumber(Util.normalize_return(vim.fn.system("tmux display -p '#{pane_at_bottom}'"))) == 1 then
		return true
	end
	return false
end

function M.go_right_pane()
	vim.fn.system("tmux select-pane -R")
end

function M.go_left_pane()
	vim.fn.system("tmux select-pane -L")
end

function M.go_down_pane()
	vim.fn.system("tmux select-pane -D")
end

-- function M.go_last_pane()
-- 	vim.fn.system("tmux last-pane")
-- end

function M.jump_to_last_pane()
	vim.fn.system("tmux last-pane")
end

function M.create_finder_target_pane()
	-- if msg == "pane-target" then
	-- [[!tmux list-panes -aF '#D #{=|6|…:session_name} #I.#P #{pane_tty} #T']],
	-- local tmux_cmd = [[!tmux list-panes -aF '\#D \#{=|6|…:session_name} \#I.\#P \#{pane_tty} \#T']]
	local tmux_cmd = [[!tmux list-panes -F '\#D \#{=|6|…:session_name} \#I.\#P \#{pane_tty} \#T']]
	-- local tmux_cmd = [[!tmux list-panes -F "\#{pane_active} \#{pane_tty}"]]
	local scripts = vim.api.nvim_exec2(tmux_cmd, { output = true })
	if scripts.output ~= nil then
		local res = vim.split(scripts.output, "\n")
		local tbl = {}
		for i = 4, #res do
			if #res > 0 then
				table.insert(tbl, res[i])
			end
		end
		return tbl
	end
end

function M.create_finder_files()
	return "fd -d 1 -e json"
end

function M.create_finder_err(output)
	return Util.rm_duplicates_tbl(output)
end

-- local function _width_pane()
-- 	local win_width = vim.api.nvim_get_option_value("lines", {})
--
-- 	local w = math.floor((win_width * 0.1) - 5)
-- 	if w < 40 then
-- 		return 55
-- 	end
-- 	return w
-- end

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
			if M.check_current_program_pane_name("yazi") then
				M.jump_to_last_pane()
				M.go_down_pane()
			end
			mode_open = "-hl"
			set_expand = true
		end
	end

	vim.fn.system("tmux split-window " .. mode_open .. " " .. size_pane .. " -c " .. cwd)
	pane_id = Util.normalize_return(vim.fn.system("tmux display -p '#{pane_id}'"))

	if M.is_pane_at_bottom() and set_expand then
		M.reset_resize_pane()
	end

	if pane_id then
		Constant.set_sendID(pane_id)
	end
end

function M.get_left_pane()
	-- M.go_right_pane()
	local pane_idx = M.get_current_pane_id()
	local pane_id = M.get_pane_id(pane_idx)

	if M.is_pane_exists(pane_idx) then
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

function M.send(content, target_pane, is_send_cmd, is_clear_sceen)
	vim.validate({ target_pane = { target_pane, "string" } })

	is_send_cmd = is_send_cmd or false

	local split_content
	local cmds

	if not M.is_pane_exists(target_pane) then
		Util.warn("Pane '" .. target_pane .. "' not exists anymore or deleted")
		return
	end

	if is_send_cmd then
		local tmux_send_cmd = "tmux send -t " .. target_pane
		local final_cmd = tmux_send_cmd .. " '" .. content .. "'" .. " Enter"
		cmds = { "sh", "-c", final_cmd }
	else
		if type(content) == "table" then
			split_content = Util.list_strip_empty_lines(content)
			cmds = { "sh", "-c", "echo '" .. table.concat(split_content, "\n") .. "' | tmux load-buffer -" }
		elseif type(content) == "string" then
			split_content = content
			cmds = { "sh", "-c", "echo '" .. split_content .. "' | tmux load-buffer -" }
		end

		if #split_content == 0 then
			-- tmux may not update the buffer with an empty string.
			-- vim.fn.system("tmux set-buffer '\n'")
			cmds = { "sh", "-c", "echo '\n' | tmux load-buffer -" }
		end
	end

	if is_clear_sceen then
		local cmd_newline = "tmux send -t" .. target_pane .. " '" .. __cmd_clear_screen() .. "' Enter "
		vim.system({ "sh", "-c", cmd_newline })
	end

	vim.system(cmds)

	if not is_send_cmd then
		vim.system({ "tmux", "paste-buffer", "-dpr", "-t", target_pane })
	end
end

function M.send_pane_cmd(task, is_clear_screen)
	vim.validate({
		task = { task, "table", true },
		isnewline = { isnewline, "boolean", true },
	})

	-- ensure cmd is not empty
	if #task.builder.cmd == 0 then
		return
	end

	local target_pane = task.pane_id
	local content = task.builder.cmd

	M.send(content, target_pane, true, is_clear_screen)
end

function M.send_interrupt(target_pane)
	local send_pane = Constant.get_sendID()
	target_pane = target_pane or send_pane

	M.send(__cmd_ctrl_c(), target_pane, true)
end

function M.send_line(target_pane)
	local send_pane = Constant.get_sendID()
	target_pane = target_pane or send_pane

	local line = vim.api.nvim_get_current_line()
	M.send(line, target_pane)
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

	-- local mode = vim.api.nvim_get_mode().mode
	--
	-- if mode == "v" or mode == "vs" or mode == "s" then
	--   -- Adjust the columns to get correct substring
	--   lines[#lines] = string.sub(lines[#lines], 1, ce)
	--   lines[1] = string.sub(lines[1], cs)
	-- elseif vim.list_contains({ "CTRL-V", "\22", "CTRL-S" }, mode) then
	--   -- Visual block mode
	--   if ce < cs then
	--     cs, ce = ce, cs
	--   end
	--   for i, line in ipairs(lines) do
	--     lines[i] = string.sub(line, cs, ce)
	--   end
	-- end
	-- V, S mode: no further processing needed

	M.send(lines, target_pane)
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

	vim.fn.system(tmux_split_cmd)

	return Util.normalize_return(vim.fn.system("tmux display -p '#{pane_id}'"))
end

function M.get_pane_width()
	return Util.normalize_return(vim.fn.system("tput cols"))
end

function M.get_pane_height()
	return Util.normalize_return(vim.fn.system("tput lines"))
end

function M.grep_err_output_commands(current_pane, target_panes, opts)
	vim.validate({
		current_pane = { current_pane, "string" },
		target_panes = { target_panes, "table" },
		opts = { opts, "table" },
	})

	local panes = target_panes
	local grep_cmd = opts.grep_cmd
	local regex = opts.regex
	local num_history_lines = opts.num_history_lines or 10000

	local results = {}

	for _, pane in ipairs(panes) do
		local pane_id = pane
		if pane_id ~= current_pane then
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
			elseif type(regex) == "table" then
				local Parser = require("overseer.parser")
				parse = Parser.new(regex)
			end

			local contents = Util.get_os_command_output({
				"sh",
				"-c",
				command_str,
			})

			if contents then
				for _, line in ipairs(contents) do
					-- parse path, line, col
					local lnum, cnum, pathx, text
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
						if results[key] == nil then
							results[key] = result
						end
					end
				end
			end
		end
	end

	return results
end

return M
