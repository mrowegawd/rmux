local Tmpl = {}
Tmpl.__index = Tmpl

function Tmpl:register()
	local user = {}
	setmetatable(user, Tmpl)
	return user
end

function Tmpl:set_template(file_rcs)
	vim.validate({
		file_rcs = { file_rcs, "table" },
	})
	self.tbl_filerc = file_rcs
end

function Tmpl:is_load()
	local is_filerc_exists = {}
	if self.tbl_filerc then
		for _, x in pairs(self.tbl_filerc) do
			if type(x) == "table" then
				if x:load() then
					table.insert(is_filerc_exists, true)
				else
					table.insert(is_filerc_exists, false)
				end
			end
		end
	end

	for i = 1, #is_filerc_exists do
		if is_filerc_exists[i] then
			return true
		end
	end

	return false
end

return Tmpl
