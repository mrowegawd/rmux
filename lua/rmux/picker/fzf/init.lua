local Util = require("rmux.utils")
local UtilFzfMapping = require("rmux.picker.fzf.mappings.utils")

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
	fzfopts.actions = {
		["default"] = UtilFzfMapping.default_target(Integs, opts),
		["ctrl-x"] = UtilFzfMapping.pane_kill(Integs),
	}
	fzfopts.fzf_opts = { ["--header"] = [[^x:killpane]] }
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

	fzfopts.fzf_opts = { ["--header"] = [[^w:watch  ^f:overseer-cmds  ^o:overseer-open]] }
	fzfopts.winopts = function()
		return {
			title = format_title(title_str, "󰑮"),
			width = 0.40,
			height = #opts + 4,
			col = 0.50,
			row = 0.50,
			fullscreen = false,
			preview = { hidden = "hidden" },
		}
	end

	fzfopts.actions = {
		["default"] = UtilFzfMapping.default_select(Integs, is_overseer),
		["ctrl-o"] = UtilFzfMapping.overseer_open(),
		["ctrl-f"] = UtilFzfMapping.overseer_cmds(title_str),
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
			local s_split
			if string.match(entry_str, "|") then
				s_split = Util.strip_whitespace(vim.split(entry_str, "|")[1])
			else
				s_split = entry_str
			end

			-- jika entry_str = ["./main.go:23:2"] = {
			--                        cnum = "2",
			--                        lnum = "23",
			--                        path = "./main.go"
			--                  },
			-- sama dengan key dari results
			local data
			for i, x in pairs(opts.results) do
				if s_split == i then
					local line
					if x.lnum == nil then
						line = 1
					end

					line = x.lnum
					data = {
						path = x.path,
						line = line,
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
		local spaces = 0
		for key, _ in pairs(opts.results) do
			if #key > spaces then
				spaces = #key
			end
		end
		for key, val in pairs(opts.results) do
			if #val.text > 0 then
				items[#items + 1] = string.format("%s%s | %s", key, (" "):rep(spaces - #key), val.text)
			else
				items[#items + 1] = key
			end
		end
		return items
	end

	local contents = format_results()

	if #contents == 0 then
		Util.info("Grep error: No results found")
		return
	end

	fzfopts.fzf_opts = { ["--header"] = [[^w:watch]] }
	fzfopts.actions = {
		["default"] = UtilFzfMapping.default_err(opts.results),
		["ctrl-s"] = UtilFzfMapping.err_open_split(opts.results),
		["ctrl-v"] = UtilFzfMapping.err_open_vsplit(opts.results),
		["ctrl-t"] = UtilFzfMapping.err_open_tab(opts.results),
		["ctrl-w"] = UtilFzfMapping.overseer_watch(Integs, is_overseer),
		["alt-q"] = UtilFzfMapping.send_to_qf(opts.results),
		["alt-Q"] = {
			prefix = "select-all+accept",
			fn = UtilFzfMapping.send_to_qf_all(opts.results),
		},
		["alt-l"] = UtilFzfMapping.send_to_loc(opts.results),
		["alt-L"] = {
			prefix = "select-all+accept",
			fn = UtilFzfMapping.send_to_loc_all(opts.results),
		},
	}

	fzflua.fzf_exec(contents, fzfopts)
end

return M
