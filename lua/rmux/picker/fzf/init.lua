local Util = require("rmux.utils")
local UtilFzfMapping = require("rmux.picker.fzf.mappings.utils")
local Constant = require("rmux.constant")

local M = {}

local fzf_lua = function()
	local has_fzf, fzf = pcall(require, "fzf-lua")
	local previewer_builtin = require("fzf-lua.previewer.builtin")
	local previewer_fzf = require("fzf-lua.previewer.fzf")

	if not has_fzf then
		Util.error("This extension requires fzf.nvim (https://github.com/ibhagwan/fzf-lua)")
		return nil, nil, nil
	end

	return fzf, previewer_fzf, previewer_builtin
end

local h = function(name)
	return vim.api.nvim_get_hl(0, { name = name })
end

-- Set hl-groups
vim.api.nvim_set_hl(0, "RmuxPromptTitle", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })
vim.api.nvim_set_hl(0, "RmuxIconTitle", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })
vim.api.nvim_set_hl(0, "RmuxNormal", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })

vim.api.nvim_set_hl(0, "RmuxPromptTitleError", { fg = h("Normal").bg, bg = h("Error").fg, italic = true, bold = true })
vim.api.nvim_set_hl(0, "RmuxIconTitleError", { fg = h("Normal").bg, bg = h("Error").fg, italic = true, bold = true })
vim.api.nvim_set_hl(0, "RmuxNormalError", { fg = h("Normal").bg, bg = h("Error").fg, italic = true, bold = true })

local function format_title(str, icon, icon_hl)
	return {
		{ " ", "RmuxNormal" },
		{ (icon and icon .. " " or ""), icon_hl or "RmuxIconTitle" },
		{ str, "RmuxPromptTitle" },
		{ " ", "RmuxNormal" },
	}
end

local function format_title_err(str, icon, icon_hl)
	return {
		{ " ", "RmuxNormalError" },
		{ (icon and icon .. " " or ""), icon_hl or "RmuxIconTitleError" },
		{ str, "RmuxPromptTitleError" },
		{ " ", "RmuxNormalError" },
	}
end

local fzfopts = {
	prompt = "  ",
	cwd_prompt = false,
	cwd_header = false,
	no_header = true,
	no_header_i = true,
	winopts = {
		-- hls = { normal = "Normal" },
		-- border = "rounded",
		height = 0.4,
		width = 0.30,
		row = 0.40,
		col = 0.55,
	},
}

function M.select_pane(Integs, opts)
	vim.validate({ opts = { opts, "table" }, Integs = { Integs, "table" } })

	local function format_results()
		local items = {}
		for i, result in pairs(opts.results) do
			if type(result) == "table" and result.builder ~= nil then
				items[#items + 1] = i .. "   " .. result.builder.name
			else
				items[#items + 1] = i
			end
		end
		return items
	end

	local fzflua, previewer_fzf, _ = fzf_lua()
	if fzflua == nil or previewer_fzf == nil then
		return
	end

	local CmdAsyncPreviewer = previewer_fzf.cmd_async:extend()
	function CmdAsyncPreviewer:new(o, optsc)
		CmdAsyncPreviewer.super.new(self, o, optsc)
		return self
	end

	function CmdAsyncPreviewer:parse_entry_and_verify(entry_str)
		if entry_str then
			local slice_str = vim.split(entry_str, " ")
			local pane_id = slice_str[1]
			local cmd_capture = Integs:run().cmd_str_capture_pane(pane_id)
			return "", "", table.concat(cmd_capture, " ")
		end
		return {}
	end

	fzfopts.previewer = {
		_ctor = function()
			return CmdAsyncPreviewer
		end,
	}
	-- fzfopts.actions = vim.tbl_extend("keep", FzfMapTarget(Integs, opts), {})

  --stylua: ignore
	fzfopts.actions = {
		["default"] = UtilFzfMapping.default_target(Integs, opts),
		["ctrl-x"] = UtilFzfMapping.pane_kill(Integs),
		["alt-x"] = function() Integs:close_all_panes() end,
	}
	fzfopts.fzf_opts = { ["--header"] = [[^x:kill-pane  a-x:kill-all-pane]] }
	fzfopts.winopts = function()
		return {
			title = format_title(opts.title, " "),
			width = 0.95,
			height = 0.80,
			col = 0.50,
			row = 0.60,
			fullscreen = false,
			preview = { horizontal = "right:40%", vertical = "down:60%" },
		}
	end

	fzflua.fzf_exec(format_results(), fzfopts)
end

function M.gen_select(Integs, opts, title, is_overseer)
	vim.validate({
		tbl = { opts, "table" },
		title = { title, "string" },
		is_overseer = { is_overseer, "boolean" },
	})

	local fzflua, _, _ = fzf_lua()
	if fzflua == nil then
		return
	end

	local title_str = title:gsub("^%l", string.upper)
	fzfopts.winopts = function()
		return {
			title = format_title(title_str, "󰑮"),
			width = 0.70,
			height = #opts + 4,
			col = 0.50,
			row = 0.50,
			fullscreen = false,
			preview = { hidden = "hidden" },
		}
	end

	fzfopts.fzf_opts = {
		["--header"] = [[^w:watch  ^f:overseer-cmds  ^o:overseer-open  ^e:grep-err  ^s:select-pane  ^d:detach!  ^v:unwatch!  a-x:kill-all-pane]],
	}

  --stylua: ignore
	fzfopts.actions = {
		["default"] = UtilFzfMapping.default_select(Integs, is_overseer),
		["alt-x"] = function() Integs:close_all_panes() end,
		["ctrl-d"] = function() Util.warn("Detach all panes!") Integs:close_all_panes(true) end,
		["ctrl-f"] = UtilFzfMapping.overseer_cmds(title_str),
		["ctrl-o"] = UtilFzfMapping.overseer_open(),
		["ctrl-s"] = function() Integs:select_target_panes() end,
		["ctrl-e"] = function() Integs:find_err() end,
		["ctrl-v"] = function() Util.info("Unwatch!") Constant.set_selected_pane({}) end,
		["ctrl-w"] = UtilFzfMapping.overseer_watch(Integs, is_overseer),
	}

	fzflua.fzf_exec(opts, fzfopts)
end

function M.grep_err(Integs, opts, is_overseer)
	vim.validate({ opts = { opts, "table" } })

	local fzflua, _, previewer_builtin = fzf_lua()
	if fzflua == nil or previewer_builtin == nil then
		return
	end

	local GrepErrPreviewer = previewer_builtin.buffer_or_file:extend()
	function GrepErrPreviewer:new(o, optsc, fzf_win)
		GrepErrPreviewer.super.new(self, o, optsc, fzf_win)
		setmetatable(self, GrepErrPreviewer)
		return self
	end

	function GrepErrPreviewer:parse_entry(entry_str)
		if entry_str then
			local s_split_str = vim.split(entry_str, ":")
			if not s_split_str then
				Util.went("An error occurred while splitting the string ':'")
				return {}
			end

			local s_split_file = Util.strip_whitespace(s_split_str[1])
			local s_split_lnum = Util.strip_whitespace(s_split_str[2])

			-- Debug output:
			--
			-- entry_str = "main.py:10:0"
			-- opts.results = {
			-- 	{
			-- 		cnum = 0,
			-- 		lnum = 10,
			-- 		path = "main.py",
			-- 		text = '  ...bunch of text..'
			-- 	},
			-- }

			-- sama dengan key dari results
			local data
			for _, x in pairs(opts.results) do
				if x.path == s_split_file and tonumber(x.lnum) == tonumber(s_split_lnum) then
					data = {
						path = x.path,
						line = x.lnum,
						col = x.cnum,
					}
				end
			end

			if data then
				return data
			end
		end

		return {}
	end

	fzfopts.previewer = {
		_ctor = function()
			return GrepErrPreviewer
		end,
	}

	fzfopts.winopts = function()
		return {
			title = format_title_err(opts.title, " "),
			width = 0.95,
			height = 0.80,
			col = 0.50,
			row = 0.60,
			fullscreen = false,
			preview = { horizontal = "right:30%", vertical = "up:60%", layout = "vertical" },
		}
	end

	local function format_results()
		local items = {}
		local max_keyname_len = 0

		for _, v in pairs(opts.results) do
			local keyname = string.format("%s:%s:%s", v.path, v.lnum, v.cnum)
			if #keyname > 0 then
				if #keyname > max_keyname_len then
					max_keyname_len = #keyname
				end
			end
		end

		for _, val in pairs(opts.results) do
			if #val.text > 0 then
				local keyname = string.format("%s:%s:%s", val.path, val.lnum, val.cnum)
				local padding = (" "):rep(max_keyname_len - #keyname)
				items[#items + 1] = string.format("%s%s | %s", keyname, padding, val.text)
			end
		end

		return items
	end

	-- Util.info(vim.inspect(opts.results))
	local contents = format_results()

	if #contents == 0 then
		Util.info("Grep error: No results found")
		return
	end

	fzfopts.fzf_opts = { ["--header"] = [[^w:watch]] }

	 --stylua: ignore
	fzfopts.actions = {
		["default"] = UtilFzfMapping.default_err(opts.results),
		["ctrl-s"] = UtilFzfMapping.err_open_split(opts.results),
		["ctrl-v"] = UtilFzfMapping.err_open_vsplit(opts.results),
		["ctrl-t"] = UtilFzfMapping.err_open_tab(opts.results),
		["ctrl-w"] = UtilFzfMapping.overseer_watch(Integs, is_overseer),
		["alt-q"] = UtilFzfMapping.send_to_qf(opts.results),
		["alt-Q"] = { prefix = "select-all+accept", fn = UtilFzfMapping.send_to_qf_all(opts.results), },
		["alt-l"] = UtilFzfMapping.send_to_loc(opts.results),
		["alt-L"] = { prefix = "select-all+accept", fn = UtilFzfMapping.send_to_loc_all(opts.results), },
	}

	fzflua.fzf_exec(contents, fzfopts)
end

return M
