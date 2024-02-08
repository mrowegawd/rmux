local Util = require("rmux.utils")
local M = {}

local list_json_tbl, current_tab_id, current_pane

local function __list_panes()
	return Util.jsonDecode(Util.normalize_return(vim.fn.system("wezterm cli list --format json")))
end

local function __get_list_panes(call_again)
	call_again = call_again or false
	if list_json_tbl == nil or call_again then
		list_json_tbl = __list_panes()
	end

	return list_json_tbl
end

local function __get_list_panes_current_tab()
	current_pane = M.get_current_pane_id()

	for _, x in pairs(__get_list_panes(true)) do
		if x.pane_id == current_pane then
			current_tab_id = x.tab_id
		end
	end

	local tbl = {}
	for _, x in pairs(__get_list_panes()) do
		if current_tab_id == x.tab_id then
			table.insert(tbl, x)
		end
	end

	return tbl
end

function M.get_pane_num(pane_id)
	return pane_id
end

function M.get_pane_id(pane_id)
	return pane_id
end

function M.get_id_next_pane(pane_are_not_main, call_again)
	local tbl = {}
	for _, x in pairs(__get_list_panes(call_again)) do
		if x.pane_id ~= pane_are_not_main and x.tab_id == current_tab_id then
			table.insert(tbl, x)
		end
	end

	if #tbl > 1 then
		return tbl[#tbl - 1].pane_id
	end
	return tbl[1].pane_id
end

function M.back_to_pane(cur_pane_id)
	vim.fn.system("wezterm cli activate-pane --pane-id " .. cur_pane_id)
end

function M.get_total_active_panes()
	local total_panes = #__get_list_panes_current_tab()
	return total_panes
end

function M.sendCtrlC()
	return "^C"
end

function M.get_current_pane_id()
	return tonumber(Util.normalize_return(vim.fn.system("wezterm cli list-clients | tail -1 | awk '{print $NF}'")))
end

function M.get_last_active_pane()
	return list_json_tbl[#list_json_tbl].pane_id
end

function M.get_right_active_pane()
	local pane_right = Util.normalize_return(vim.fn.system("wezterm cli get-pane-direction right"))
	if #pane_right == 0 then
		return nil, false
	end
	return pane_right, true
end

function M.pane_exists(pane_id)
	for _, x in pairs(__list_panes()) do
		if x.pane_id == pane_id then
			return true
		end
	end
	return false
end

function M.kill_pane(pane_id)
	vim.fn.system("wezterm cli kill-pane --pane-id " .. pane_id)
end

function M.pane_iszoom()
	-- TODO: check zoom atau tidak, bisa dilihat di `wezterm cli list --format json`
	return Util.normalize_return(vim.fn.system([[tmux display-message -p "#F"]])) == "*Z"
end
function M.pane_toggle_zoom()
	return Util.normalize_return(vim.fn.system([[wezterm cli zoom-pane]]))
end

function M.sendEnter(pane_id)
	vim.fn.system("wezterm cli send-text --no-paste $'\r' --pane-id " .. pane_id)
end

function M.pane_capture(pane_num, grep_cmd)
	local cmd = [[!wezterm cli get-text --pane-id ]] .. pane_num .. " | sort -r | grep -oiE '" .. grep_cmd .. "' | tac"
	return vim.api.nvim_exec2(cmd, { output = true })
end
function M.create_finder_err(output)
	return Util.rm_duplicates_tbl(output)
end

return M
