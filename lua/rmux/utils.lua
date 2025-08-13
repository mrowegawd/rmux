local M = {}

local Job = require("plenary.job")

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

function M.run_jobstart(command, on_stdout)
	vim.fn.jobstart(command, {
		on_stdout = on_stdout,
		on_stderr = on_stdout,
		stdout_buffered = false,
		stderr_buffered = false,
	})
end

function M.normalize_return(str)
	---@diagnostic disable-next-line: redefined-local
	local str_slice = string.gsub(str, "\n", "")
	local res = vim.split(str_slice, "\n")
	if res[1] then
		return res[1]
	end

	return str_slice
end

function M.get_os_command_output(cmd, cwd)
	if type(cmd) ~= "table" then
		M.warn("cmd has to be a table")
		return {}
	end

	local command = table.remove(cmd, 1)
	local stderr = {}
	local stdout, ret = Job:new({
		command = command,
		args = cmd,
		cwd = cwd,
		on_stderr = function(_, data)
			table.insert(stderr, data)
		end,
	}):sync()
	return stdout, ret, stderr
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
function M.jsonEncode(tbl)
	return vim.fn.json_encode(tbl)
end
function M.jsonDecode(tbl)
	return vim.fn.json_decode(tbl)
end

function M.read_json_file(tbl)
	return M.jsonDecode(vim.fn.readfile(tbl))
end

function M.write_to_file(tbl, path_fname)
	local tbl_json = M.read_json_file(tbl)
	vim.fn.writefile({ tbl_json }, path_fname)
end

--  ╭──────────────────────────────────────────────────────────╮
--  │                         LOGGING                          │
--  ╰──────────────────────────────────────────────────────────╯

function M.warn(msg)
	vim.validate({ msg = { msg, "string" } })
	vim.notify(msg, vim.log.levels.WARN, { title = "RMUX" })
end

function M.error(msg)
	vim.validate({ msg = { msg, "string" } })
	vim.notify(msg, vim.log.levels.ERROR, { title = "RMUX" })
end

function M.info(msg)
	vim.validate({ msg = { msg, "string" } })
	vim.notify(msg, vim.log.levels.INFO, { title = "RMUX" })
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
