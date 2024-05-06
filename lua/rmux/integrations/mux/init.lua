local Util = require("rmux.utils")
local Constant = require("rmux.constant")

local M = {}
function M.pane_iszoom()
	return Util.normalize_return(vim.fn.system([[tmux display-message -p "#F"]])) == "*Z"
end

function M.pane_toggle_zoom()
	return Util.normalize_return(vim.fn.system([[tmux resize-pane -Z]]))
end

function M.pane_capture(pane_num, grep_cmd)
	local cmd = [[!tmux capture-pane -pJS - -t ]] .. pane_num .. " | sort -r | grep -oiE '" .. grep_cmd .. "' | tac"
	return vim.api.nvim_exec2(cmd, { output = true })
end

function M.pane_exists(pane_id)
	vim.validate({
		pane_id = { pane_id, "string" },
	})
	return not (Util.normalize_return(vim.fn.system("tmux display -t " .. pane_id .. " -p '#{pane_id}'")) == "")
	-- return not (
	-- 	Util.normalize_return(vim.fn.system("tmux has-session -t " .. pane_idx .. " 2>/dev/null && echo 123")) == ""
	-- )
end

function M.get_pane_id(pane_idx)
	vim.validate({
		pane_idx = { tonumber(pane_idx), "number" },
	})
	local pane_id = Util.normalize_return(vim.fn.system("tmux display -t " .. pane_idx .. " -p '#{pane_id}'"))

	if pane_id:match("%%") then
		return pane_id
	elseif #pane_id == 0 then
		Util.warn({ msg = "pane_idx (index pane) is nil, its not active anymore" })
		return
	else
		Util.warn({ msg = "pane_id: " .. tostring(pane_id) .. " must contains with %" })
		return
	end
end

function M.get_pane_idx(pane_id)
	vim.validate({
		pane_id = { pane_id, "string" },
	})

	return Util.normalize_return(vim.fn.system("tmux display -t " .. pane_id .. " -p '#{pane_index}'"))
end

function M.is_pane_not_exists(pane_id)
	vim.validate({
		pane_id = { pane_id, "string" },
	})

	return M.pane_exists(M.get_pane_idx(pane_id))
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
	-- return tonumber(Util.normalize_return(vim.fn.system("tmux display-message -p '#{window_panes}'")))
	return tonumber(Util.normalize_return(vim.fn.system("tmux list-panes | wc -l")))
end

function M.get_last_active_pane()
	return Util.normalize_return(vim.fn.system("tmux list-panes | tail -1 | cut -d':' -f1"))
end

function M.get_current_pane_id()
	return Util.normalize_return(vim.fn.system([[tmux list-panes | grep "active" | cut -d':' -f1]]))
end

function M.pane_cmd(cmd)
	return Util.normalize_return(Util.normalize_return(vim.fn.system(cmd)))
end

function M.get_id_next_pane()
	-- Jika terdapat 2 pane yang aktif, ambil 'the next' pane id number nya
	return Util.normalize_return(vim.fn.system("tmux list-panes | grep -v 'active' | cut -d' ' -f7 | head -n 1"))
end

function M.get_pane_target(pane_idx)
	vim.validate({
		pane_idx = { tonumber(pane_idx), "number" },
	})
	return Util.normalize_return(vim.fn.system("tmux display-message -t " .. pane_idx .. ' -p "#{pane_id}"'))
end

function M.kill_pane(pane_id)
	if #pane_id > 0 then
		return vim.fn.system("tmux kill-pane -t " .. pane_id)
	end
end

function M.sendCtrlC()
	return "^C"
end

function M.sendClearScreen()
	return "clear"
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

function M.back_to_pane(pane_idx)
	pane_idx = pane_idx or 1

	vim.validate({
		pane_idx = { tonumber(pane_idx), "number" },
	})
	vim.fn.system("tmux select-pane -t " .. pane_idx)
end

function M.check_right_pane_current_command()
	M.go_right_pane()
	return Util.normalize_return(
		vim.fn.system([[tmux display -p "#{pane_id} #{pane_current_command}" | awk '$2 == "zsh" { print $2; exit }']])
	)
end

function M.check_right_pane_id()
	M.go_right_pane()
	return Util.normalize_return(vim.fn.system([[tmux display -p "#{pane_id}"]]))
end

function M.go_right_pane()
	vim.fn.system("tmux select-pane -R")
end
function M.go_left_pane()
	vim.fn.system("tmux select-pane -L")
end
function M.go_last_pane()
	vim.fn.system("tmux last-pane")
end

local function _width_pane()
	local win_width = vim.api.nvim_get_option_value("lines", {})

	local w = math.floor((win_width * 0.1) - 5)
	if w < 40 then
		return 55
	end
	return w
end

function M.create_new_pane()
	local current_right_pane_command = M.check_right_pane_current_command()
	if current_right_pane_command == "" then
		-- print("yes go right and open pane")
		local pane_id = Util.normalize_return(
			vim.fn.system(
				string.format(
					"tmux split-window -h -p %s -l %s -c '#{pane_current_path}' | tmux display -p '#{pane_id}'",
					_width_pane(),
					_width_pane()
				)
			)
		)

		Constant.set_sendID(pane_id)
		M.back_to_pane()
	elseif current_right_pane_command == "zsh" then
		-- print("already opened pane and current pane command is zsh")
		M.get_left_pane()
		M.back_to_pane()
	end
end

function M.get_left_pane()
	-- M.go_right_pane()
	local pane_idx = M.get_current_pane_id()
	local pane_id = M.get_pane_id(pane_idx)

	if M.pane_exists(pane_idx) then
		Constant.set_sendID(pane_id)
	end
end

function M.send_pane_cmd(pane_id, cmd_nvim, isnewline)
	isnewline = isnewline or false
	vim.validate({
		pane_id = { pane_id, "string", true },
		cmd_nvim = { cmd_nvim, "string", true },
	})

	if not M.pane_exists(pane_id) then
		Util.warn({ msg = pane_id .. " pane not exist" })
		return
	end

	if isnewline then
		vim.fn.system("tmux send -t" .. pane_id .. " '" .. M.sendClearScreen() .. "' Enter ")
	end

	-- NOTE: cmd_nvim berisi question marks dalam ouputnya
	-- jadi mesti hilangkan terlebih dahulu,
	cmd_nvim = string.gsub(cmd_nvim, '"', "")

	local tmux_sendcmd = "tmux send -t " .. pane_id
	local final_cmd = tmux_sendcmd .. " '" .. cmd_nvim .. "'" .. " Enter"
	vim.fn.system(final_cmd)
end

function M.update_keys_task(task_tbl_panes, lang_task)
	task_tbl_panes.builder = lang_task.builder({})
	task_tbl_panes.name = lang_task.name
	local pane_id = Constant.get_sendID()
	task_tbl_panes.pane_id = pane_id
	Constant.set_sendID(pane_id)

	if not M.pane_exists(task_tbl_panes.pane_id) then
		M.go_right_pane()
		task_tbl_panes.pane_id = pane_id
	end
	M.go_left_pane()
end

function M.send_interrupt()
	local pane_id = Constant.get_sendID()
	M.send_pane_cmd(pane_id, M.sendCtrlC())
end

function M.send_line()
	local send_pane = Constant.get_sendID()

	local linenr = vim.api.nvim_win_get_cursor(0)[1]
	vim.cmd("silent! " .. linenr .. "," .. linenr .. " :w  !tmux load-buffer -")
	vim.fn.system("tmux paste-buffer -dpr -t " .. send_pane)
end

function M.send_range_line()
	local send_pane = Constant.get_sendID()

	if M.pane_iszoom() then
		M.pane_toggle_zoom()
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

function M.open_vertical_pane(pane_strategy, size)
	vim.validate({
		pane_strategy = { pane_strategy, "string" },
		size = { size, "number" },
	})

	local tmux_split_cmd = "tmux split-window " .. pane_strategy .. " -l " .. tostring(size)
	if pane_strategy == "-h" then
		-- tmux_split_cmd = "tmux split-window " .. pane_strategy .. " -l " .. tostring(size)
		tmux_split_cmd = "tmux split-window " .. pane_strategy
	end

	-- print(tmux_split_cmd)
	vim.fn.system(tmux_split_cmd)

	return Util.normalize_return(vim.fn.system("tmux display -p '#{pane_id}'"))
end

function M.get_pane_width()
	return Util.normalize_return(vim.fn.system("tput cols"))
end

function M.get_pane_height()
	return Util.normalize_return(vim.fn.system("tput lines"))
end

return M
