local has_fzf, fzf = pcall(require, "fzf-lua")
if not has_fzf then
	error("This extension requires fzf.nvim (https://github.com/ibhagwan/fzf-lua)")
end

local previewer_builtin = require("fzf-lua.previewer.builtin")
local previewer_fzf = require("fzf-lua.previewer.fzf")

local FzfMapSelect = require("rmux.picker.fzf.mappings.select")
local FzfmapGrepErr = require("rmux.picker.fzf.mappings.greperr")
-- local FzfMapPane = require("rmux.picker.fzf.mappings.pane")
local FzfMapTarget = require("rmux.picker.fzf.mappings.target")

local M = {}

local function h(name)
	return vim.api.nvim_get_hl(0, { name = name })
end

-- set hl-groups
vim.api.nvim_set_hl(0, "RunmuxPromptTitle", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })
vim.api.nvim_set_hl(0, "RunmuxIconTitle", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })
vim.api.nvim_set_hl(0, "RunmuxNormal", { fg = h("Normal").bg, bg = h("Normal").fg, italic = true, bold = true })
function M.check_bottom_pane()
	print(M.is_pane_at_bottom())
end

local function format_title(str, icon, icon_hl)
	return {
		{ " ", "RunmuxNormal" },
		{ (icon and icon .. " " or ""), icon_hl or "RunmuxIconTitle" },
		{ str, "RunmuxPromptTitle" },
		{ " ", "RunmuxNormal" },
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
		border = "rounded",
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
	fzfopts.actions = vim.tbl_extend("keep", FzfMapTarget(Integs, opts), {})
	fzfopts.fzf_opts = { ["--header"] = [[^x:deletepane]] }
	fzfopts.winopts = function()
		return {
			title = format_title(opts.title, " "),
			width = 0.95,
			height = 0.80,
			col = 0.50,
			row = 0.60,
			preview = { horizontal = "right:50%", vertical = "down:50%" },
		}
	end

	fzf.fzf_exec(format_results(), fzfopts)
end

-- function M.select_rmuxfile()
-- 	local Term = require("rmux." .. Config.settings.base.run_with .. ".util")
--
-- 	local titleMsg = "Load rmux from storage"
-- 	fzfopts.cwd = Config.settings.base.rmuxpath
-- 	fzfopts.fzf_opts = { ["--header"] = [[^x:deletejson]] }
-- 	fzfopts.cmd = Term.create_finder_files()
-- 	fzfopts.actions = vim.tbl_extend("keep", FzfMapPane.enter(), FzfMapPane.delete())
-- 	fzfopts.winopts = function()
-- 		local cols = vim.o.columns - 50
-- 		local collss = cols > 80 and cols / 2 - 25 or cols
-- 		return {
-- 			width = 100,
-- 			height = 25,
-- 			row = 10,
-- 			col = collss,
-- 			title = format_title(titleMsg:gsub("^%l", string.upper), ""),
-- 		}
-- 	end

function M.gen_select(Integs, tbl, title, is_overseer)
	vim.validate({
		tbl = { tbl, "table" },
		title = { title, "string" },
		is_overseer = { is_overseer, "boolean" },
	})

	local title_str = title:gsub("^%l", string.upper)

	fzfopts.fzf_opts = { ["--header"] = [[^r:watch  ^o:overseercommands]] }
	fzfopts.winopts = function()
		return {
			title = format_title(title_str, "󰑮"),
			width = 0.40,
			height = #tbl + 4,
			col = 0.50,
			row = 0.50,
			preview = { hidden = "hidden" },
		}
	end

	fzfopts.actions = vim.tbl_extend("keep", FzfMapSelect(Integs, title_str, is_overseer), {})

	fzf.fzf_exec(tbl, fzfopts)
end

function M.grep_err(opts)
	vim.validate({ opts = { opts, "table" } })

	local function format_results()
		local items = {}
		for i, _ in pairs(opts.results) do
			items[#items + 1] = i
		end
		return items
	end

	local GrepErrPreviewer = previewer_builtin.buffer_or_file:extend()
	function GrepErrPreviewer:new(o, optsc, fzf_win)
		GrepErrPreviewer.super.new(self, o, optsc, fzf_win)
		setmetatable(self, GrepErrPreviewer)
		return self
	end

	function GrepErrPreviewer:parse_entry(entry_str)
		if entry_str then
			-- jika entry_str = ["./main.go:23:2"] = {
			--                        cnum = "2",
			--                        lnum = "23",
			--                        path = "./main.go"
			--                  },
			-- sama dengan key dari results
			local data
			for i, x in pairs(opts.results) do
				if entry_str == i then
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
	fzfopts.fzf_opts = { ["--header"] = [[^v:opvert  ^s:opsplit  ^t:optab]] }
	fzfopts.winopts = function()
		return {
			title = format_title(opts.title, " "),
			width = 0.95,
			height = 0.80,
			col = 0.50,
			row = 0.60,
			preview = { horizontal = "right:50%", vertical = "down:50%" },
		}
	end

	fzfopts.actions = vim.tbl_extend("keep", FzfmapGrepErr(opts.results), {})

	fzf.fzf_exec(format_results(), fzfopts)
end

return M
