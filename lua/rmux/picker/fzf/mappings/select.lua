local Integs = require("rmux.integrations")

local M = {}

function M.enter()
	return {
		["default"] = function(selected, _)
			Integs:generator_cmd_panes(selected[1])
		end,

		-- ["alt-a"] = function()
		-- 	Integs:run_all(tbl, "orchestrator")
		-- end,
	}
end

return M
