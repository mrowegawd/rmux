local Config = require("rmux.config")
local Constant = require("rmux.constant")
local Util = require("rmux.utils")

local RMuxjson = {}
RMuxjson.__index = RMuxjson

local overseer_vscode = require("overseer.template.vscode")
-- local vs_util = require("overseer.template.vscode.vs_util")

local json_data
local file_rc

-- local function validateJsonKeys(json_decode_data, expectKeys)
-- 	for key, _ in pairs(json_decode_data) do
-- 		if not expectKeys[key] then
-- 			return false
-- 		end
-- 	end
-- 	return true
-- end

-- TODO: function ini harus di ubah
local function check_keys_decode_data_json(json_decode_data)
	local requiredKeys = { "label", "command", "problemMatcher" }
	local allKeysValid = true
	local invalidKeys = {}

	for _, reqkey in ipairs(requiredKeys) do
		for _, tasks in pairs(json_decode_data.tasks) do
			if not tasks[reqkey] then
				allKeysValid = false
				table.insert(invalidKeys, reqkey)
			end
		end
	end

	if not allKeysValid then
		local _invalid_keys = Util.remove_duplicate_tbl(invalidKeys)
		local invalidKeysStr = table.concat(_invalid_keys, ", ")
		local errorMsg = "The following keys .rmuxrc.json are missing or invalid: " .. invalidKeysStr
		Util.error(errorMsg)
		return false
	end
	return true
end

function RMuxjson:is_taskjson_exists()
	file_rc = Config.settings.base.fullpath .. "/" .. Config.settings.base.file_rc
	return Util.exists(file_rc)
end

function RMuxjson:load()
	if self:is_taskjson_exists() then
		json_data = Util.read_json_file(file_rc)

		if check_keys_decode_data_json(json_data) then
			local tbl_data = {}
			for _, task in pairs(json_data.tasks) do
				-- print(vim.inspect(task))
				-- TODO: field 'pane' seharus nya di convert saat overseer.convert_vscode_task()??
				local output_task = overseer_vscode.convert_vscode_task(task)
				table.insert(tbl_data, output_task)
			end

			Constant.set_template_provider("rmux")
			Constant.insert_tbl_tasks(tbl_data)
			return true
		end

		return false
	end

	return false
end

return RMuxjson
