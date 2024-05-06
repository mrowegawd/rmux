local has_overseer, _ = pcall(require, "overseer")
if not has_overseer then
	error("This extension requires overseer.nvim (https://github.com/stevearc/overseer.nvim)")
end

local Constant = require("rmux.constant")
local overseer_vscode = require("overseer.template.vscode")

local VScode = {}
VScode.__index = VScode

function VScode:is_taskjson_exists()
	return overseer_vscode.condition.callback({})
end

function VScode:load()
	if self:is_taskjson_exists() then
		overseer_vscode.generator({}, function(tbl_data)
			Constant.insert_tbl_langs(tbl_data)
		end)

		return true
	end
	return false
end

return VScode
