local function get_col_and_row(x)
	local line, col
	if x.lnum ~= nil then
		line = x.lnum
	else
		line = 1
	end

	if x.cnum ~= nil then
		col = x.cnum
	else
		col = 1
	end
	return tonumber(line), tonumber(col)
end

return function(results)
	return {
		["default"] = function(selected, _)
			if selected[1] == nil then
				return
			end
			local sel = selected[1]
			for i, x in pairs(results) do
				if sel == i then
					local line, col = get_col_and_row(x)
					vim.cmd("e " .. x.path)
					vim.api.nvim_win_set_cursor(0, { line, col })
					break
				end
			end
		end,
		["ctrl-s"] = function(selected, _)
			if selected[1] == nil then
				return
			end
			local sel = selected[1]
			for i, x in pairs(results) do
				if sel == i then
					local line, col = get_col_and_row(x)
					vim.cmd("sp " .. x.path)
					vim.api.nvim_win_set_cursor(0, { line, col })
					break
				end
			end
		end,
		["ctrl-v"] = function(selected, _)
			if selected[1] == nil then
				return
			end
			local sel = selected[1]
			for i, x in pairs(results) do
				if sel == i then
					local line, col = get_col_and_row(x)
					vim.cmd("vsp " .. x.path)
					vim.api.nvim_win_set_cursor(0, { line, col })
					break
				end
			end
		end,
		["ctrl-t"] = function(selected, _)
			if selected[1] == nil then
				return
			end
			local sel = selected[1]
			for i, x in pairs(results) do
				if sel == i then
					local line, col = get_col_and_row(x)
					vim.cmd("tabnew " .. x.path)
					vim.api.nvim_win_set_cursor(0, { line, col })
					break
				end
			end
		end,
	}
end
