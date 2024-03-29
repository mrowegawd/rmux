local Util = require("rmux.utils")

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

function M.pane_exists(pane_num)
	-- return not (Util.normalize_return(vim.fn.system("tmux display-message -t " .. pane_num .. " -p '#{pane_id}'")) == "")
	return not (
		Util.normalize_return(vim.fn.system("tmux has-session -t " .. pane_num .. " 2>/dev/null && echo 123")) == ""
	)
end

function M.get_pane_id(pane_num)
	return Util.normalize_return(vim.fn.system("tmux display-message -t " .. pane_num .. " -p '#{pane_id}'"))
end

function M.get_pane_num(pane_id)
	return Util.normalize_return(vim.fn.system("tmux display-message -t " .. pane_id .. " -p '#{pane_index}'"))
end

function M.get_pane_current_command(pane_id)
	return Util.normalize_return(
		vim.fn.system("tmux display-message -t " .. pane_id .. " -p '#{pane_current_command}'")
	)
end

function M.get_total_active_panes()
	return tonumber(Util.normalize_return(vim.fn.system("tmux display-message -p '#{window_panes}'")))
end

function M.get_last_active_pane()
	return Util.normalize_return(vim.fn.system("tmux list-panes | tail -1 | cut -d':' -f1"))
end

function M.get_current_pane_id()
	return Util.normalize_return(vim.fn.system([[tmux list-panes | grep "active" | cut -d':' -f1]]))
end

-- function M.pane_cmd(cmd)
-- 	return Util.normalize_return(Util.normalize_return(vim.fn.system(cmd)))
-- end

function M.get_id_next_pane()
	-- Jika terdapat 2 pane yang aktif, ambil 'the next' pane id number nya
	return Util.normalize_return(vim.fn.system("tmux list-panes | grep -v 'active' | cut -d' ' -f7 | head -n 1"))
end

function M.get_pane_target(pane_num)
	return Util.normalize_return(vim.fn.system("tmux display-message -t " .. pane_num .. ' -p "#{pane_id}"'))
end

function M.kill_pane(pane_id)
	if #pane_id > 0 then
		return vim.fn.system("tmux kill-pane -t " .. pane_id)
	end
end

-- function M.fix_pane_closed()
-- 	if M.get_total_panes() == 1 then
-- 		Util.warn({ msg = "Create another pane please", setnotif = true })
-- 		return false
-- 	end

-- 	return true
-- end

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

function M.back_to_pane(cur_pane_id)
	vim.fn.system("tmux select-pane -t " .. cur_pane_id)
end

function M.get_right_active_pane()
	print(M.get_total_active_panes())
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

return M
