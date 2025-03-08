return function(Integs, title_str, is_overseer)
	return {
		["default"] = function(selected, _)
			if is_overseer then
				vim.cmd(selected[1])
				return
			end
			Integs:generator_cmd_panes(selected[1])
		end,
		["ctrl-r"] = function()
			if is_overseer then
				vim.cmd("OverseerOpen")
				return
			end
			Integs:watcher()
		end,
		["ctrl-o"] = function()
			if is_overseer then
				vim.cmd("OverseerOpen")
				return
			end

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
					preview = { hidden = "hidden" },
				},
				actions = {
					["default"] = function(sel, _)
						vim.cmd(sel[1])
					end,
				},
			})
		end,
	}
end
