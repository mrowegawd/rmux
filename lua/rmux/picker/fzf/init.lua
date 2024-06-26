local has_fzf, fzf = pcall(require, "fzf-lua")
if not has_fzf then
	error("This extension requires fzf.nvim (https://github.com/ibhagwan/fzf-lua)")
end

local Config = require("rmux.config")

local FzfMapPane = require("rmux.picker.fzf.mappings.pane")
local FzfMapSelect = require("rmux.picker.fzf.mappings.select")
local FzfMapTarget = require("rmux.picker.fzf.mappings.target")
local Fzfmap_grepper = require("rmux.picker.fzf.mappings.greperr")
local FzfmapUtils = require("rmux.picker.fzf.utils")

local M = {}

local function format_title(str, icon, icon_hl)
	return {
		{ " " },
		{ (icon and icon .. " " or ""), icon_hl or "DevIconDefault" },
		{ str, "Bold" },
		{ " " },
	}
end

local fzfopts = {
	prompt = "   ",
	cwd_prompt = false,
	cwd_header = false,
	no_header = true,
	no_header_i = true,
	winopts = {
		hl = { normal = "Normal" },
		border = "rounded",
		height = 0.4,
		width = 0.30,
		row = 0.40,
		col = 0.55,
	},
}

function M.target_pane()
	local Term = require("rmux." .. Config.settings.base.run_with .. ".util")
	local titleMsg = "pane-target"

	fzfopts.winopts.title = format_title(titleMsg:gsub("^%l", string.upper), "", "Boolean")
	fzfopts.actions = vim.tbl_extend("keep", FzfMapTarget.select(), FzfMapTarget.delete())
	fzfopts.fzf_opts = { ["--header"] = [[Ctrl-x:'delete pane']] }
	fzfopts.winopts.preview = { hidden = "hidden" }
	fzfopts.winopts_fn = function()
		local cols = vim.o.columns - 50
		local collss = cols > 80 and cols - 80 or cols / 2
		return { width = 60, height = 15, row = 15, col = collss }
	end
	fzf.fzf_exec(Term.create_finder_target_pane(), fzfopts)
end

function M.select_rmuxfile()
	local Term = require("rmux." .. Config.settings.base.run_with .. ".util")

	local titleMsg = "Load rmux from storage"
	fzfopts.winopts.title = format_title(titleMsg:gsub("^%l", string.upper), "", "Boolean")
	fzfopts.cwd = Config.settings.base.rmuxpath
	fzfopts.fzf_opts = { ["--header"] = [[Ctrl-x:'delete json']] }
	fzfopts.cmd = Term.create_finder_files()
	fzfopts.actions = vim.tbl_extend("keep", FzfMapPane.enter(), FzfMapPane.delete())
	fzfopts.winopts_fn = function()
		local cols = vim.o.columns - 50
		local collss = cols > 80 and cols / 2 - 25 or cols
		return { width = 100, height = 25, row = 10, col = collss }
	end
	fzf.files(fzfopts)
end

function M.gen_select(tbl, title)
	vim.validate({
		tbl = { tbl, "table" },
		title = { title, "string" },
	})

	local col, row = FzfmapUtils.get_col_row()

	-- fzfopts.fzf_opts = { ["--header"] = [[ Alt-a: Run All | Alt-c: Kill All]] }
	fzfopts.winopts_fn = function()
		return {
			title = format_title(title:gsub("^%l", string.upper), "", "Boolean"),
			width = 60,
			height = 25,
			col = col,
			row = row,
		}
	end
	fzfopts.actions = vim.tbl_extend("keep", FzfMapSelect.enter(), {})

	-- NOTE: gabungkan dengan built command seperti `watcher`,
	-- pada `tbl`
	fzf.fzf_exec(tbl, fzfopts)
end

function M.grep_err(opts, pane_num)
	local Term = require("rmux." .. Config.settings.base.run_with .. ".util")
	opts = opts or {}
	local titleMsg = "Select errors [" .. pane_num .. "]"

	local path_cwd
	if #Config.settings.base.rmuxpath > 0 then
		path_cwd = Config.settings.base.rmuxpath
	end

	if path_cwd == nil then
		return
	end

	local col, row = FzfmapUtils.get_col_row()

	fzfopts.winopts.title = format_title(titleMsg:gsub("^%l", string.upper), "", "Boolean")
	fzfopts.actions = vim.tbl_extend("keep", {}, Fzfmap_grepper.enter(), Fzfmap_grepper.send_qf())
	-- fzfopts.fzf_opts = {
	-- 	["--header"] = [[default:'go-to-file']],
	-- 	["--no-sort"] = "",
	-- }
	fzfopts.sort = true
	fzfopts.winopts.preview = { hidden = "hidden" }
	fzfopts.winopts_fn = function()
		local win_height = math.ceil(vim.api.nvim_get_option_value("lines", {}) * 0.5)
		local win_width = math.ceil(vim.api.nvim_get_option_value("columns", {}) * 1)
		return {
			width = win_width,
			height = win_height,
			row = row,
			col = col,
		}
	end

	fzf.fzf_exec(Term.create_finder_err(opts), fzfopts)
end

return M
