local M = {}
local Constant = require("rmux.constant")
local Fzf = require("rmux.picker.fzf")

function M.generator_select(tbl)
	vim.validate({
		tbl = { tbl, "table" },
	})
	-- return vim.ui.select(tbl, {
	-- 	prompt = "Select tasks:",
	-- }, function(a)
	-- 	print(a)
	-- end)
	return Fzf.gen_select(tbl)
end

function M.load_tasks_list()
	local langs = Constant.get_langs()
	local task_names = {}
	for _, x in pairs(langs) do
		if x["name"] then
			table.insert(task_names, x.name)
		end
	end
	M.generator_select(task_names)

	return "asdfa "
end

return M
