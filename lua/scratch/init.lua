local M = {}

---@param opts { args: string[] | string, type?: "text" }
---@param bufnr number?
local function make_scratch(opts, bufnr)
	bufnr = bufnr or 0

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false

	if opts.type == "text" then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, opts.args)
		return
	end

	local args = tostring(opts.args)
	if args == "" then return end
	args = args:gsub("^!", "")
	vim.cmd("0read !" .. args)
end

---@param bufnr number?
local function is_buf_in_view(bufnr)
	local win_list = vim.fn.win_findbuf(bufnr)
	return #win_list > 0
end

---@param opts { args: string[] | string, type?: "text" }
---@param bufnr number?
function M.new_buf(opts, bufnr)
	if bufnr then
		vim.api.nvim_set_current_buf(bufnr)
	else
		vim.cmd("enew")
	end
	make_scratch(opts, bufnr)
end

---@param opts { args: string[] | string, type?: "text" }
---@param bufnr number?
function M.new_vsplit(opts, bufnr)
	if bufnr ~= nil then
		if not is_buf_in_view(bufnr) then
			vim.cmd('vertical sbuffer ' .. bufnr)
		end
	else
		vim.cmd("vnew")
	end
	make_scratch(opts, bufnr)
end

---@param opts { args: string[] | string, type?: "text" }
---@param bufnr number?
function M.new_hsplit(opts, bufnr)
	if bufnr ~= nil then
		if not is_buf_in_view(bufnr) then
			vim.cmd('sbuffer ' .. bufnr)
		end
	else
		vim.cmd("split")
	end
	make_scratch(opts, bufnr)
end

function M.new_float(opts, wopts)
	local bufnr = vim.api.nvim_create_buf(false, true)

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

	local win = vim.api.nvim_open_win(bufnr, true, wopts)

	make_scratch(opts, bufnr)

	return {win, bufnr}
end

return M
