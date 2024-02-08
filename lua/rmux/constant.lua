local Config = require("rmux.config")

local M = {}

function M.set_insert_tbl_opened_panes(pane_id, pane_num, open_pane, state_cmd, command, regex)
	vim.validate({
		pane_id = { pane_id, "string", true },
		open_num = { type(tonumber(pane_num)), "string", true },
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

function M.get_tbl_opened_panes()
	return Config.settings.base.tbl_opened_panes
	-- local _tbl = {}
	--
	-- for _, panes in pairs(Config.settings.base.tbl_opened_panes) do
	-- 	if panes.state_cmd == state_cmd then
	-- 		_tbl = panes
	-- 	end
	-- end
	-- return _tbl
end

function M.update_tbl_opened_panes(fn)
	for idx, pane in pairs(Config.settings.base.tbl_opened_panes) do
		fn(idx, pane)
	end
end

---------------------

function M.set_sendID(send_pane)
	if Config.settings.base.run_with == "mux" then
		assert(
			type(send_pane) == "string",
			"Config.settings.base.sendID=" .. send_pane .. " but 'send_pane must be type of string"
		)
		local persent, _ = string.find(send_pane, [[%%]])
		assert(persent == 1, "Config.settings.base.sendID=" .. send_pane .. " but 'sendID' must have prefix with %")
	else
		assert(
			type(send_pane) == "number",
			"Config.settings.base.sendID=" .. tostring(send_pane) .. " but 'send_pane' must be type of number"
		)
	end

	Config.settings.sendID = send_pane
end

function M.get_sendID()
	return Config.settings.sendID
end

---------------------
function M.find_state_cmd_on_tbl_opened_panes(state_cmd)
	-- assert(#Config.settings.base.tbl_opened_panes > 0, "get_tbl_opened_panes must greater than zero")
	for _, value in pairs(Config.settings.base.tbl_opened_panes) do
		if value.state_cmd == state_cmd then
			return value
		end
	end
end

return M
