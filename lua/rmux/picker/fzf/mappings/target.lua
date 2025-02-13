local Constant = require("rmux.constant")
local Util = require("rmux.utils")

return function(Integs, opts)
	return {
		["default"] = function(selected, _)
			if #selected == 0 then
				return
			end

			local pane_id = {}
			local msg_selected_pane

			if #selected == 1 then
				local slice_str = vim.split(selected[1], " ")
				pane_id[#pane_id + 1] = slice_str[1]
				msg_selected_pane = slice_str[1]
			end

			if #selected > 1 then
				for _, x in pairs(selected) do
					local slice_str = vim.split(x, " ")
					pane_id[#pane_id + 1] = slice_str[1]
					msg_selected_pane = "[ " .. table.concat(pane_id, " ") .. " ]"
				end
			end

			Constant.set_selected_pane(pane_id)
			Util.info({ msg = "Select pane: " .. msg_selected_pane, setnotif = true })
		end,
		["ctrl-x"] = function(selected, _)
			if selected[1] == nil then
				return
			end
			local slice_str = vim.split(selected[1], " ")
			local pane_id = slice_str[1]

			if pane_id then
				Integs.kill_pane(pane_id)
			end

			-- TODO: update table tbl_opened_panes tasks nya karena sudah di delete
		end,
	}
end
