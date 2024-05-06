local Config = require("rmux.config")
local Util = require("rmux.utils")
local Constant = require("rmux.constant")

-- local Muxutil = require("rmux.integrations.mux.util")

local M = {}

function M.select()
	return {
		["default"] = function(selected, _)
			print("yes")
			-- if selected[1] == nil then
			-- 	return
			-- end
			-- local pane_extnum = string.match(selected[1], "%s%d.%d")
			--
			-- local pane_number = pane_extnum:match("%d$")
			-- Constant.set_sendID(Muxutil.get_pane_id(pane_number))
			--
			-- ---@diagnostic disable-next-line: unused-local
			-- Constant.update_tbl_opened_panes(function(idx, pane)
			-- 	if pane.state_cmd == Config.settings.provider_cmd.RUN_FILE then
			-- 		pane.pane_id = Constant.get_sendID()
			-- 	end
			-- end)
			--
			-- local is_regex = "off"
			-- local tbl_opened_panes = Config.settings.base.tbl_opened_panes
			-- for i, _ in pairs(tbl_opened_panes) do
			-- 	local pane_id = tbl_opened_panes[i].pane_id
			-- 	local regex = tbl_opened_panes[i].regex
			-- 	if pane_id == Constant.get_sendID() then
			-- 		if #regex > 0 then
			-- 			is_regex = "on"
			-- 		end
			-- 	end
			-- end
			--
			-- Util.info({
			-- 	msg = "Pane_num: " .. pane_number .. "\nPane_id: " .. Constant.get_sendID() .. "\nRegex: " .. is_regex,
			-- 	setnotif = true,
			-- })
		end,
	}
end

function M.delete()
	return {
		["ctrl-x"] = function(selected, _)
			print("yes")
			-- local sel = tostring(selected[1])
			--
			-- local pane_extnum = string.match(sel, "%s%d.%d%s")
			--
			-- local panenum = string.match(tostring(pane_extnum), "%d%s$")
			--
			-- -- print(pane_extnum .. " .. " .. panenum)
			-- if panenum ~= nil then
			-- 	Muxutil.kill_pane(panenum)
			-- 	require("fzf-lua").resume()
			-- end
		end,
	}
end

return M
