local scratch = require("scratch")

vim.api.nvim_create_user_command("Scratch", scratch.new_buf, { nargs = "*" })
vim.api.nvim_create_user_command("VScratch", scratch.new_vsplit, { nargs = "*" })
vim.api.nvim_create_user_command("HScratch", scratch.new_hsplit, { nargs = "*" })

local is_floating_created = false

vim.api.nvim_create_user_command("FScratch", function (opts)
	if is_floating_created then
		vim.api.nvim_err_writeln("Floating scratch already exists. Please close old one to create new.")
		return
	end

	is_floating_created = true

	local main_win = vim.api.nvim_get_current_win()
	local win_buf = scratch.new_float(opts)
	local win, buf = win_buf[1], win_buf[2]

	local function jump_gf()
		local file = vim.fn.expand("<cfile>")
		if vim.fn.filereadable(file) == 1 then
			if vim.api.nvim_win_is_valid(main_win) then
				vim.api.nvim_set_current_win(main_win)
				vim.cmd("edit " .. file)
			end
		end
	end

	vim.keymap.set("n", "gf", jump_gf, { buffer = buf, noremap = true, silent = true })

	vim.keymap.set("n", "q", function()
		is_floating_created = false
		vim.api.nvim_win_close(0, true)
	end, { buffer = buf })

	vim.api.nvim_create_autocmd("WinClosed", {
		callback = function(args)
			if tonumber(args.match) == win then
				is_floating_created = false
			end
		end,
	})

	vim.keymap.set("n", "<c-j>", function()
		local ui = vim.api.nvim_list_uis()[1]
		local config = vim.api.nvim_win_get_config(win)
		local new_row = config.row + 1

		vim.api.nvim_win_set_config(win, {
			relative = "editor",
			row = math.min(new_row, ui.height - config.height),
			col = config.col
		})
	end, { buffer = buf })

	vim.keymap.set("n", "<c-k>", function()
		local config = vim.api.nvim_win_get_config(win)
		local new_row = config.row - 1

		vim.api.nvim_win_set_config(win, {
			relative = "editor",
			row = math.max(new_row, 0),
			col = config.col
		})
	end, { buffer = buf })

	vim.keymap.set("n", "<c-h>", function()
		local config = vim.api.nvim_win_get_config(win)
		local new_col = config.col - 1

		vim.api.nvim_win_set_config(win, {
			relative = "editor",
			col = math.max(new_col, 0),
			row = config.row
		})
	end, { buffer = buf })

	vim.keymap.set("n", "<c-l>", function()
		local ui = vim.api.nvim_list_uis()[1]
		local config = vim.api.nvim_win_get_config(win)
		local new_col = config.col + 1

		vim.api.nvim_win_set_config(win, {
			relative = "editor",
			col = math.min(new_col, ui.width - config.width),
			row = config.row
		})
	end, { buffer = buf })

	vim.api.nvim_create_user_command("FocusScratch", function ()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_set_current_win(win)
		end
	end, { nargs = "*" })
end, { nargs = "*" })
