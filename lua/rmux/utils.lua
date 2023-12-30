local M = {}
local buf

--  ╭──────────────────────────────────────────────────────────╮
--  │                         GENERALS                         │
--  ╰──────────────────────────────────────────────────────────╯

local function require_gitsigns()
	local HAVE_GITSIGNS = pcall(require, "gitsigns")
	if HAVE_GITSIGNS then
		return true
	end
	return false
end

function M.get_root_path()
	local gitsign_load = require_gitsigns()

	local status

	if vim.b["gitsigns_status_dict"] ~= nil then
		status = vim.b["gitsigns_status_dict"]
	end

	local path

	if not gitsign_load or status == nil or status ~= nil and status["root"] == nil then
		path = vim.fn.getcwd()
	else
		path = status["root"]
	end

	return path
end

function M.remove_duplicate_tbl(tbl)
	local hash = {}
	local res = {}

	for _, v in ipairs(tbl) do
		if not hash[v] then
			res[#res + 1] = v -- you could print here instead of saving to result table if you wanted
			hash[v] = true
		end
	end

	return res
end

function M.rm_duplicates_tbl(arr)
	local newArray = {}
	local checkerTbl = {}
	for _, element in ipairs(arr) do
		-- [[if there is not yet a value at the index of element, then it will
		-- be nil, which will operate like false in an if statement
		-- ]]
		if not checkerTbl[element] then
			checkerTbl[element] = true
			table.insert(newArray, element)
		end
	end
	return newArray
end

function M.tablelength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

local function create_win()
	vim.api.nvim_command("botright vnew")
	--  win = vim.api.nvim_get_current_win()
	buf = vim.api.nvim_get_current_buf()

	vim.api.nvim_buf_set_name(0, "result #" .. buf)

	vim.api.nvim_buf_set_option(0, "buftype", "nofile")
	vim.api.nvim_buf_set_option(0, "swapfile", false)
	-- vim.api.nvim_buf_set_option(0, "filetype", filetype)
	vim.api.nvim_buf_set_option(0, "bufhidden", "wipe")

	vim.api.nvim_command("setlocal wrap")
	-- vim.api.nvim_command("setlocal cursorline")
end
local function on_stdout(_, data)
	if data then
		for _, line in ipairs(data) do
			if line ~= "" then
				vim.api.nvim_buf_set_lines(buf, -1, -1, false, { line })
			end
		end
	end
end

function M.run_script_async(command)
	create_win()
	vim.fn.jobstart(command, {
		on_stdout = on_stdout,
		on_stderr = on_stdout,
		stdout_buffered = false,
		stderr_buffered = false,
	})
end

--  ╭──────────────────────────────────────────────────────────╮
--  │                        FILE UTILS                        │
--  ╰──────────────────────────────────────────────────────────╯

function M.exists(filename)
	local stat = vim.loop.fs_stat(filename)
	return stat and stat.type or false
end

function M.is_dir(filename)
	return M.exists(filename) == "directory"
end

function M.is_file(filename)
	return M.exists(filename) == "file"
end

function M.read_json_file(tbl)
	return vim.fn.json_decode(vim.fn.readfile(tbl))
end

function M.write_to_file(tbl, path_fname)
	local tbl_json = M.read_json_file(tbl)
	vim.fn.writefile({ tbl_json }, path_fname)
end

--  ╭──────────────────────────────────────────────────────────╮
--  │                         LOGGING                          │
--  ╰──────────────────────────────────────────────────────────╯

function M.warn(opts)
	if type(opts) ~= "table" then
		print("type must be a table")
	end

	local notif = opts.setnotif or false
	if notif then
		vim.notify(opts.msg, vim.log.levels.WARN, { title = "RMUX" })
	end
end

function M.error(opts)
	if type(opts) ~= "table" then
		print("type must be a table")
	end

	local notif = opts.setnotif or false
	if notif then
		vim.notify(opts.msg, vim.log.levels.ERROR, { title = "RMUX" })
	end
end

function M.info(opts)
	if type(opts) ~= "table" then
		print("type must be a table")
	end

	local notif = opts.setnotif or false
	if notif then
		vim.notify(opts.msg, vim.log.levels.INFO, { title = "RMUX" })
	end
end

--  ╭──────────────────────────────────────────────────────────╮
--  │                          LINES                           │
--  ╰──────────────────────────────────────────────────────────╯

---@param mode "visual" | "motion"
---@return table
function M.get_line_selection(mode)
	---@diagnostic disable-next-line: deprecated
	local start_char, end_char = unpack(({
		visual = { "'<", "'>" },
		motion = { "'[", "']" },
	})[mode])

	-- Get the start and the end of the selection
	---@diagnostic disable-next-line: deprecated
	local start_line, start_col = unpack(vim.fn.getpos(start_char), 2, 3)
	---@diagnostic disable-next-line: deprecated
	local end_line, end_col = unpack(vim.fn.getpos(end_char), 2, 3)
	local selected_lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	return {
		start_pos = { start_line, start_col },
		end_pos = { end_line, end_col },
		selected_lines = selected_lines,
	}
end

return M
