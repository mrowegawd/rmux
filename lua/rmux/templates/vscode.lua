local has_overseer, _ = pcall(require, "overseer")
if not has_overseer then
	error("This extension requires overseer.nvim (https://github.com/stevearc/overseer.nvim)")
end

local Constant = require("rmux.constant")
local Util = require("rmux.utils")

local overseer_vscode = require("overseer.template.vscode")

local Settings = Constant.get_settings()

local file_rc = ".vscode/tasks.json"
local file_rc_path = Settings.base.fullpath .. "/" .. file_rc

local VScode = {}
VScode.__index = VScode

function VScode:is_taskjson_exists()
	return overseer_vscode.condition.callback({})
end

function VScode:load()
	if not Util.is_file(file_rc_path) then
		return false
	end

	if self:is_taskjson_exists() then
		overseer_vscode.generator({}, function(tbl_data)
			Constant.insert_tbl_tasks(tbl_data)
		end)

		Constant.set_template_provider("vscode")
		Constant.set_file_rc(file_rc)
		return true
	end
	return false
end

return VScode
