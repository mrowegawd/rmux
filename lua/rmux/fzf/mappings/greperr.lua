local Util = require("rmux.utils")
local M = {}

function M.enter()
	return {
		["default"] = function(selected, _)
			local sel = selected[1]:match(".*:[0-9]+:[0-9]+")

			-- local filename = sel:match(".[a-zA-Z0-9_/]+.go")

			local fname = vim.fn.split(sel, ":")
			local row = tonumber(fname[2])
			local col = tonumber(fname[3])

			if col == nil then
				col = 0
			end
			if row == nil then
				row = 1
			end

			vim.cmd("e " .. fname[1])
			vim.api.nvim_win_set_cursor(0, { row, col })
		end,
	}
end

-- check:
-- format string error itu harus seperti ini:
-- - ./main.go:7:13: undefined nothing
-- - ./main.go:7:13: undefined: sdfI
-- jangan yang seperti ini:
-- - ./main.go:7:13 undefined: sdfI     <-- kurang titik dua `..:7:13`
-- - ./main.go:7 undefined: sdfI        <-- kurang col nya
function M.send_qf()
	return {
		["ctrl-q"] = function(selected, _)
			if #selected == 0 then
				return
			end

			local _tbl = {}
			for _, sel in pairs(selected) do
				local colname, _ = string.match(sel, "[a-z].*:[0-9]")
				local sel_split = vim.split(colname, ":")
				if sel_split[3] == nil then
					sel_split[3] = 0
				end

				local text_ = string.gsub(sel, "[a-z%.%/0-9].*:[0-9]: ", "")
				table.insert(_tbl, { filename = sel_split[1], lnum = sel_split[2], col = sel_split[3], text = text_ })
			end

			local action = "r" -- (a) append, (r) replace, " "
			local what = {
				items = Util.rm_duplicates_tbl(_tbl),
				title = "Error",
			}

			vim.fn.setqflist({}, action, what)
			vim.cmd("copen")
		end,
	}
end

return M
