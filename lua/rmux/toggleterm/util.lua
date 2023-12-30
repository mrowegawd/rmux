local Util = require("rmux.utils")
local toggleterm = require("toggleterm.terminal")
local Path = require("plenary.path")
local toggleterm_ui = require("toggleterm.ui")

local M = {}

function M.get_total_active_panes()
	print("not implemented yet")
	return 0
end

--- Get the list of terminals and their properties.
--- @return table, table A tuple containing a list of toggleterm/terminal objects and a table of options that will be used for
--- creating the telescope entries.
function M.get_terminals()
	local terms = toggleterm.get_all(true)
	if #terms == 0 then
		return {}, {}
	end
	local terminals = {}
	local entry_maker_opts = {}
	local bufnrs, term_name_lengths, bufname_lengths = {}, {}, {}

	local cwd = vim.fn.expand(vim.loop.cwd())

	for _, term in ipairs(terms) do
		-- local id = vim.api.nvim_buf_get_var(term, "toggle_number")
		-- local term = toggleterm.get(id)

		local info = vim.fn.getbufinfo(term.bufnr)[1]

		local flag = (term.bufnr == vim.fn.bufnr("") and "%") or (term.bufnr == vim.fn.bufnr("#") and "#" or "")
		local visibility = info.hidden == 1 and "h" or "a"
		local state = flag .. visibility

		local term_name = term.display_name or tostring(term.id)

		local bufname = info.name ~= "" and info.name or "No Name"
		bufname = Path:new(bufname):normalize(cwd) -- if bufname is inside the cwd, trim that part of the string

		table.insert(bufnrs, term.bufnr)
		table.insert(term_name_lengths, #term_name)
		table.insert(bufname_lengths, #info.name)

		if flag ~= "" then
			entry_maker_opts.flag_exists = true
		end

		term._info, term._state, term._term_name, term._bufname = info, state, term_name, bufname
		table.insert(terminals, term)
	end

	---@diagnostic disable-next-line: deprecated
	entry_maker_opts.max_term_name_width = math.max(unpack(term_name_lengths))
	---@diagnostic disable-next-line: deprecated
	entry_maker_opts.max_bufnr_width = #tostring(math.max(unpack(bufnrs)))
	---@diagnostic disable-next-line: deprecated
	entry_maker_opts.max_bufname_width = math.max(unpack(bufname_lengths))

	return terminals, entry_maker_opts
end

-- function M.get_panes()
-- 	return M.get_terminals()
-- end

function M.create_finder()
	local terms, entry_maker_opts = M.get_terminals()

	local new_row_num
	if terms and #terms > 0 then
		local sort_field = "term_name"
		local ascending = true
		local sort_funcs = {
			bufnr = function(a, b)
				if ascending then
					return a.bufnr < b.bufnr
				end
				return a.bufnr > b.bufnr
			end,
			state = function(a, b)
				if ascending then
					return a._state < b._state
				end
				return a._state > b._state
			end,
			recency = function(a, b)
				if ascending then
					return a._info.lastused < b._info.lastused
				end
				return a._info.lastused > b._info.lastused
			end,
			term_name = function(a, b)
				local numA = tonumber(a._term_name)
				local numB = tonumber(b._term_name)

				local result
				if numA and numB then
					if ascending then
						result = numA < numB
					else
						result = numA > numB
					end
				elseif numA then
					result = ascending
				elseif numB then
					result = not ascending
				else
					if ascending then
						result = a._term_name < b._term_name
					else
						result = a._term_name > b._term_name
					end
				end

				return result
			end,
		}

		table.sort(terms, sort_funcs[sort_field])

		for i, term in ipairs(terms) do
			print(term.id)
		end
	end
end

function M.open_toggleterm(id, direction)
	id = id or 1

	local Terminal = require("toggleterm.terminal").Terminal

	local dir
	if dir and vim.fn.isdirectory(vim.fn.expand(dir)) == 0 then
		dir = nil
	end

	return Terminal:new({ id = id, direction = direction }):toggle()
end

function M.close_toggleterm()
	-- TODO: jika terspawn beberapa term, apakah harus di close semua?
	vim.cmd([[ToggleTerm]])
end

function M.term_has_windows(term)
	return toggleterm_ui.find_open_windows(function(buf)
		return buf == term.bufnr
	end)
end

function M.get_term_all()
	return toggleterm.get_all()
end
function M.create_finder_files()
	return "fd -d 1 -e json"
end

function M.create_finder_err(output)
	return Util.rm_duplicates_tbl(output)
end

return M
