local M = {}

function M.enter()
	return {
		["default"] = function(selected, _)
			local sel = selected[1]:match(".*:[0-9]+:[0-9]+")

			-- local filename = sel:match(".[a-zA-Z0-9_/]+.go")

			local fname = vim.fn.split(sel, ":")
			local row = tonumber(fname[2])
			local col = tonumber(fname[3])

			-- local line_count = vim.api.nvim_buf_line_count(0)
			-- if row < line_count then
			-- 	row = row + 1
			-- end

			vim.cmd("e " .. fname[1])
			vim.api.nvim_win_set_cursor(0, { row, col })
		end,
	}
end

-- function M.delete()
-- 	return {
-- 		["default"] = function(selected, _)
-- 			print(selected[1])
-- 		end,
-- 	}
-- end

return M
