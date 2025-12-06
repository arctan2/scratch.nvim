local M = {}

local function make_scratch_and_run_cmd(opts, bufnr)
	bufnr = bufnr or 0

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false

	if opts.args == "" then return end

	local cmd = opts.args:gsub("^!", "")
	vim.cmd("0read !" .. cmd)
end

function M.new_buf(opts)
	vim.cmd("enew")
	make_scratch_and_run_cmd(opts)
end

function M.new_vsplit(opts)
	vim.cmd("vnew")
	make_scratch_and_run_cmd(opts)
end

function M.new_hsplit(opts)
	vim.cmd("split")
	make_scratch_and_run_cmd(opts)
end

function M.new_float(opts, wopts)
	local buf = vim.api.nvim_create_buf(false, true)

	local width = math.floor(vim.o.columns * 0.3)
	local height = math.floor(vim.o.lines * 0.3)

	wopts = wopts or {
		style = "minimal",
		relative = "editor",
		width = width,
		height = height,
		row = 0,
		col = vim.o.columns - width,
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, wopts)

	make_scratch_and_run_cmd(opts, buf)

	return {win, buf}
end

return M
