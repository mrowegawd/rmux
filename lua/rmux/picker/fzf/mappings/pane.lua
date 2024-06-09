local Config = require("rmux.config")
local Util = require("rmux.utils")
local FzfMapUtils = require("rmux.picker.fzf.utils")

local M = {}

function M.enter()
	return {
		["default"] = function(selected, _)
			local pth = FzfMapUtils.__strip_str(selected[1])
			if pth == nil then
				return
			end
			local muxrc_json = Config.settings.base.rmuxpath .. "/" .. pth

			vim.cmd("e " .. Config.settings.base.file_rc)
			vim.cmd("1,$d") -- delete all line in a file
			vim.cmd("0r! cat " .. muxrc_json)
			vim.cmd("0")
		end,
		["ctrl-e"] = function(selected, _)
			local pth = FzfMapUtils.__strip_str(selected[1])
			if pth == nil then
				return
			end

			local muxrc_json = Config.settings.base.rmuxpath .. "/" .. pth
			vim.cmd("e " .. muxrc_json)
		end,
	}
end

function M.delete()
	return {
		["ctrl-x"] = function(selected, _)
			local pth = FzfMapUtils.__strip_str(selected[1])
			if pth == nil then
				return
			end

			local muxrc_json = Config.settings.base.rmuxpath .. "/" .. pth

			if Util.is_file(muxrc_json) then
				local cmd = "!rm"
				vim.api.nvim_exec2(cmd .. " " .. muxrc_json, { output = true })
				require("fzf-lua").resume()
			end
		end,
	}
end
return M
