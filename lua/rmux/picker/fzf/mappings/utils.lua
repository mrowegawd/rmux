local Constant = require("rmux.constant")
local Util = require("rmux.utils")

local M = {}

local str_filter = function(sel)
	local s_split_str = vim.split(sel, ":")
	if not s_split_str then
		Util.went("An error occurred while splitting the string ':'")
		return {}
	end

	local s_split_file = Util.strip_whitespace(s_split_str[1])
	local s_split_lnum = Util.strip_whitespace(s_split_str[2])
	return s_split_file, s_split_lnum
end

local process_selected_result = function(results, selection, func)
	local sel
	if type(selection) == "string" then
		sel = selection
	end
	if type(selection) == "table" then
		sel = selection[1]
	end

	local s_file, s_lnum = str_filter(sel)

	for _, x in pairs(results) do
		if x.path == s_file and tonumber(x.lnum) == tonumber(s_lnum) then
			return func(x)
		end
	end
end

local data_for_quickfix = function(results, selection, func)
	process_selected_result(results, selection, func)
end

-- ╭─────────────────────────────────────────────────────────╮
-- │                        OVERSEER                         │
-- ╰─────────────────────────────────────────────────────────╯

function M.overseer_open()
	return function()
		vim.cmd("OverseerToggle")
	end
end

function M.overseer_watch(Integs, is_overseer)
	return function()
		if is_overseer then
			vim.cmd("OverseerOpen")
			return
		end
		Integs:watcher()
	end
end

function M.overseer_cmds(title_str)
	return function()
		local global_commands = vim.api.nvim_get_commands({})
		local overseer_cmds = {}
		for idx, _ in pairs(global_commands) do
			if string.match(idx, "Overseer") then
				overseer_cmds[#overseer_cmds + 1] = idx
			end
		end

		require("fzf-lua").fzf_exec(overseer_cmds, {
			winopts = {
				title = " " .. title_str .. ":Overseer ",
				width = 0.40,
				height = #overseer_cmds + 2,
				col = 0.50,
				row = 0.50,
				fullscreen = false,
				---@diagnostic disable-next-line: assign-type-mismatch
				preview = { hidden = "hidden" },
			},
			actions = {
				["default"] = function(sel, _)
					vim.cmd(sel[1])
				end,
			},
		})
	end
end

-- ╭─────────────────────────────────────────────────────────╮
-- │                        GENERALS                         │
-- ╰─────────────────────────────────────────────────────────╯

function M.default_target(Integs, opts)
	return function(selected)
		if #selected == 0 then
			return
		end

		local pane_id = {}
		local msg_selected_pane

		if #selected == 1 then
			local slice_str = vim.split(selected[1], " ")
			pane_id[#pane_id + 1] = slice_str[1]
			msg_selected_pane = slice_str[1]
		end

		if #selected > 1 then
			for _, x in pairs(selected) do
				local slice_str = vim.split(x, " ")
				pane_id[#pane_id + 1] = slice_str[1]
				msg_selected_pane = "[ " .. table.concat(pane_id, " ") .. " ]"
			end
		end

		Constant.set_selected_pane(pane_id)

		if opts.is_watcher then
			Constant.set_watcher_status(opts.is_watcher)
			Integs:set_au_watcher()
			Util.info("Set watcher pane: " .. msg_selected_pane)
		else
			Util.info("Select pane: " .. msg_selected_pane)
		end
	end
end

function M.default_select(Integs, is_overseer)
	return function(selected, _)
		if is_overseer then
			vim.cmd(selected[1])
			return
		end
		Integs:generator_cmd_panes(selected[1])
	end
end

function M.default_err(results)
	return function(selected, _)
		if selected[1] == nil then
			return
		end

		process_selected_result(results, selected, function(x)
			vim.cmd("e " .. x.path)
			vim.api.nvim_win_set_cursor(0, { x.lnum, x.cnum })
		end)
	end
end

function M.pane_kill(Integs)
	return function(selected)
		if selected[1] == nil then
			return
		end
		local slice_str = vim.split(selected[1], " ")
		local pane_id = slice_str[1]

		if pane_id then
			Integs:kill_pane(pane_id)
		end

		-- NOTE: reload need it
		-- require("fzf-lua").actions.resume()
	end
end

-- ╭─────────────────────────────────────────────────────────╮
-- │                         ERRORS                          │
-- ╰─────────────────────────────────────────────────────────╯

function M.err_open_split(results)
	return function(selected, _)
		if selected[1] == nil then
			return
		end

		process_selected_result(results, selected, function(x)
			vim.cmd("sp " .. x.path)
			vim.api.nvim_win_set_cursor(0, { x.lnum, x.cnum })
		end)
	end
end

function M.err_open_vsplit(results)
	return function(selected, _)
		if selected[1] == nil then
			return
		end

		process_selected_result(results, selected, function(x)
			vim.cmd("vsp " .. x.path)
			vim.api.nvim_win_set_cursor(0, { x.lnum, x.cnum })
		end)
	end
end

function M.err_open_tab(results)
	return function(selected, _)
		if selected[1] == nil then
			return
		end

		process_selected_result(results, selected, function(x)
			vim.cmd("tabnew" .. x.path)
			vim.api.nvim_win_set_cursor(0, { x.lnum, x.cnum })
		end)
	end
end

-- ╭─────────────────────────────────────────────────────────╮
-- │                         QF/LOC                          │
-- ╰─────────────────────────────────────────────────────────╯

function M.send_to_qf(results)
	return function(selected, _)
		local items = {}

		if #selected > 1 then
			for _, sel in pairs(selected) do
				data_for_quickfix(results, sel, function(x)
					items[#items + 1] = {
						filename = x.path,
						lnum = x.lnum,
						col = x.cnum,
						text = x.text,
					}
				end)
			end
		else
			data_for_quickfix(results, selected, function(x)
				items[#items + 1] = {
					filename = x.path,
					lnum = x.lnum,
					col = x.cnum,
					text = x.text,
				}
			end)
		end

		local what = {
			idx = "$",
			items = items,
			title = "Grep errors",
		}

		vim.fn.setqflist({}, "r", what)
		vim.cmd(Constant.open_qf())
	end
end

function M.send_to_qf_all(results)
	return function(selected, _)
		local items = {}

		for _, sel in pairs(selected) do
			data_for_quickfix(results, sel, function(x)
				items[#items + 1] = {
					filename = x.path,
					lnum = x.lnum,
					col = x.cnum,
					text = x.text,
				}
			end)
		end

		local what = {
			idx = "$",
			items = items,
			title = "Grep errors (all)",
		}

		vim.fn.setqflist({}, "r", what)
		vim.cmd(Constant.open_qf())
	end
end

function M.send_to_loc(results)
	return function(selected, _)
		local items = {}

		if #selected > 1 then
			for _, sel in pairs(selected) do
				data_for_quickfix(results, sel, function(x)
					items[#items + 1] = {
						filename = x.path,
						lnum = x.lnum,
						col = x.cnum,
						text = x.text,
					}
				end)
			end
		else
			data_for_quickfix(results, selected, function(x)
				items[#items + 1] = {
					filename = x.path,
					lnum = x.lnum,
					col = x.cnum,
					text = x.text,
				}
			end)
		end

		vim.fn.setloclist(0, {}, " ", {
			nr = "$",
			items = items,
			title = "Grep errors",
		})
		vim.cmd(Constant.open_loc())
	end
end

function M.send_to_loc_all(results)
	return function(selected, _)
		local items = {}

		for _, sel in pairs(selected) do
			data_for_quickfix(results, sel, function(x)
				items[#items + 1] = {
					filename = x.path,
					lnum = x.lnum,
					col = x.cnum,
					text = x.text,
				}
			end)
		end

		vim.fn.setloclist(0, {}, " ", {
			nr = "$",
			items = items,
			title = "Grep errors (all)",
		})
		vim.cmd(Constant.open_loc())
	end
end

return M
