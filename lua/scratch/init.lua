local M = {}

---@param opts { args: string[] | string, type?: "text", mode?: "append" }
---@param bufnr number?
local function make_scratch(opts, bufnr)
	bufnr = bufnr or 0

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false

	if opts.type == "text" then
		local start = opts.mode == "append" and -1 or 0
		vim.api.nvim_buf_set_lines(bufnr, start, -1, false, opts.args)
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

---@param bufnr number
local function focus_to_buf(bufnr)
	local win_id = vim.fn.win_findbuf(bufnr)[1]
	if win_id then
		vim.api.nvim_set_current_win(win_id)
	end
	vim.api.nvim_set_current_buf(bufnr)
end

---@return number
---@param opts { args: string[] | string, type?: "text", mode?: "append" }
---@param bufnr number?
function M.new_buf(opts, bufnr)
	if bufnr == nil then
		bufnr = vim.api.nvim_create_buf(true, true)
	end

	vim.api.nvim_set_current_buf(bufnr)

	make_scratch(opts, bufnr)
	focus_to_buf(bufnr)

	return bufnr
end


---@return number
---@param opts { args: string[] | string, type?: "text", mode?: "append" }
---@param bufnr number?
function M.new_vsplit(opts, bufnr)
	if bufnr == nil then
		bufnr = vim.api.nvim_create_buf(true, true)
	end

	if not is_buf_in_view(bufnr) then
		vim.cmd('vertical sbuffer ' .. bufnr)
	end

	make_scratch(opts, bufnr)
	focus_to_buf(bufnr)

	return bufnr
end

---@return number
---@param opts { args: string[] | string, type?: "text", mode?: "append" }
---@param bufnr number?
function M.new_hsplit(opts, bufnr)
	if bufnr == nil then
		bufnr = vim.api.nvim_create_buf(true, true)
	end

	if not is_buf_in_view(bufnr) then
		vim.cmd('sbuffer ' .. bufnr)
	end

	make_scratch(opts, bufnr)
	focus_to_buf(bufnr)

	return bufnr
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
