local Tmpl = {}
Tmpl.__index = Tmpl

function Tmpl:register()
	local user = {}
	setmetatable(user, Tmpl)
	return user
end

function Tmpl:set_template(tbl_providers)
	vim.validate({ tbl_providers = { tbl_providers, "table" } })
	self.tbl_template_providers = tbl_providers
end

function Tmpl:is_load()
	local is_filerc_exists = false
	if self.tbl_template_providers then
		for _, template in pairs(self.tbl_template_providers) do
			if type(template) == "table" then
				if template:load() then
					is_filerc_exists = true
				end
			end
		end
	end

	return is_filerc_exists
end

return Tmpl
