local M = {}

---@param s string
local function remove_escape_seq(s)
	return s:gsub('\x1b%[%d+;%d+;%d+;%d+;%d+m','')
	:gsub('\x1b%[%d+;%d+;%d+;%d+m','')
	:gsub('\x1b%[%d+;%d+;%d+m','')
	:gsub('\x1b%[%d+;%d+m','')
	:gsub('\x1b%[%d+m','')
end

---@param arr string[]
---@param first number?
---@param last number?
local function slice_with_escape_seq_removal(arr, first, last)
    local sliced = {}
    for i = first or 1, last or #arr do
        sliced[#sliced+1] = remove_escape_seq(arr[i])
    end
    return sliced
end

---@param args string
local function args_to_str(args)
	args = tostring(args)
	return args:gsub("^!", "")
end

local function clean_terminal_unlisted_bufs()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local is_unlisted = not vim.bo[bufnr].buflisted
		local is_terminal = vim.bo[bufnr].buftype == 'terminal'
		local is_hidden = #vim.fn.win_findbuf(bufnr) == 0
		if is_unlisted and not (is_hidden and is_terminal) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end
end

local function compile_name(name)
	return "Compile: "..name
end

local function scratch_name(name)
	return "Scratch: "..name
end

local function scroll_window_to_bottom(win_id)
	if win_id > -1 then
		local buf = vim.api.nvim_win_get_buf(win_id)
		local line_count = vim.api.nvim_buf_line_count(buf)
		vim.api.nvim_win_set_cursor(win_id, {line_count, 0})
	end
end

---@class Opts
---@field args string | string[]
---@field type? "text" | "terminal"
---@field mode? "append"

---@param opts Opts
---@param bufnr number?
---@return number
local function make_scratch(opts, bufnr)
	bufnr = bufnr or 0

	local function try_stop_job()
		local id = vim.bo[bufnr].channel
		if id then
			vim.fn.jobstop(id)
		end

		id = vim.b[bufnr].scratch_job_id
		if id then
			vim.fn.jobstop(id)
		end
	end

	try_stop_job()

	local function try_stop_job_delete_buf()
		if vim.api.nvim_buf_is_valid(bufnr) then
			try_stop_job()
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(bufnr) then
					vim.bo[bufnr].buflisted = false
					vim.api.nvim_buf_delete(bufnr, { force = true })
				end
				clean_terminal_unlisted_bufs()
			end)
		end
	end

	vim.keymap.set("n", "<c-x>", try_stop_job_delete_buf, { buffer = bufnr })

	if opts.type == "text" then
		local start = opts.mode == "append" and -1 or 0
		vim.api.nvim_buf_set_lines(bufnr, start, -1, false, opts.args)
		return bufnr
	end

	local args = args_to_str(opts.args) ---@diagnostic disable-line
	if args == "" then return bufnr end

	local scroll_to_end = function ()
		scroll_window_to_bottom(vim.fn.bufwinid(bufnr))
	end

	local on_stdout = function(_, data, _)
		if vim.api.nvim_buf_is_valid(bufnr) then
			data = slice_with_escape_seq_removal(data, 1, #data - 1)
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
			scroll_to_end()
		end
	end

	local on_stderr = function(_, data, _)
		if vim.api.nvim_buf_is_valid(bufnr) then
			data = slice_with_escape_seq_removal(data, 1, #data - 1)
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
			scroll_to_end()
		end
	end

	local on_exit = function(_, exit_code)
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"", "Completed with exit code "..exit_code, ""})
			scroll_to_end()
		end
	end

	local check_buf_and_scroll_end = function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			scroll_to_end()
		end
	end

	local delete_old_create_new_buf = function (old_buf)
		local win_id = vim.fn.bufwinid(old_buf)
		local new_buf = vim.api.nvim_create_buf(true, true)
		vim.bo[new_buf].bufhidden = "hide"
		vim.bo[new_buf].swapfile = false
		vim.api.nvim_win_set_buf(win_id, new_buf)
		if vim.api.nvim_buf_is_valid(old_buf) then
			vim.api.nvim_buf_delete(old_buf, { force = true })
		end
		vim.keymap.set("n", "<c-x>", try_stop_job_delete_buf, { buffer = new_buf })
		vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
			buffer = new_buf,
			callback = function()
				vim.cmd("stopinsert")
			end,
		})
		return new_buf
	end

	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false

	if opts.type == "terminal" then
		bufnr = delete_old_create_new_buf(bufnr)

		vim.b[bufnr].scratch_job_id = vim.fn.jobstart(args, {
			term = true,
			on_stdout = check_buf_and_scroll_end,
			on_stderr = check_buf_and_scroll_end,
			on_exit = check_buf_and_scroll_end,
		})
		vim.api.nvim_buf_set_name(bufnr, compile_name(args))
	else
		vim.bo[bufnr].buftype = "nofile"
		vim.api.nvim_buf_set_lines(0, 0, -1, true, {})
		vim.b[bufnr].scratch_job_id = vim.fn.jobstart(args, {
			stdout_buffered = false,
			on_stdout = on_stdout,
			on_stderr = on_stderr,
			on_exit = on_exit,
		})
		vim.api.nvim_buf_set_name(bufnr, scratch_name(args))
	end

	vim.api.nvim_create_autocmd({ "BufDelete" }, {
		buffer = bufnr,
		callback = try_stop_job_delete_buf,
	})

	vim.keymap.set("n", "<c-c>", try_stop_job, { buffer = bufnr })
	return bufnr
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

---@param bufnr number?
---@param name string
---@return number
local function create_bufnr_if_not_exist_by_name(bufnr, name)
	if bufnr == nil then
		bufnr = vim.fn.bufnr(compile_name(name))
		if bufnr == -1 then
			bufnr = vim.fn.bufnr(scratch_name(name))
		end

		if bufnr == -1 or name == "" then
			bufnr = vim.api.nvim_create_buf(true, true)
		end
	end
	return bufnr
end

---@return number
---@param opts Opts
---@param bufnr number?
function M.new_buf(opts, bufnr)
	bufnr = create_bufnr_if_not_exist_by_name(bufnr, args_to_str(opts.args)) ---@diagnostic disable-line
	vim.api.nvim_set_current_buf(bufnr)
	bufnr = make_scratch(opts, bufnr)
	focus_to_buf(bufnr)
	return bufnr
end

---@return number
---@param opts Opts
---@param bufnr number?
function M.new_vsplit(opts, bufnr)
	bufnr = create_bufnr_if_not_exist_by_name(bufnr, args_to_str(opts.args)) ---@diagnostic disable-line
	if not is_buf_in_view(bufnr) then
		vim.cmd('vertical sbuffer ' .. bufnr)
	end
	bufnr = make_scratch(opts, bufnr)
	focus_to_buf(bufnr)
	return bufnr
end

---@return number
---@param opts Opts
---@param bufnr number?
function M.new_hsplit(opts, bufnr)
	bufnr = create_bufnr_if_not_exist_by_name(bufnr, args_to_str(opts.args)) ---@diagnostic disable-line
	if not is_buf_in_view(bufnr) then
		vim.cmd('sbuffer ' .. bufnr)
	end
	bufnr = make_scratch(opts, bufnr)
	focus_to_buf(bufnr)
	return bufnr
end

---@return number
---@param opts Opts
---@param bufnr number?
function M.compile_new_buf(opts, bufnr)
	opts.type = "terminal"
	return M.new_buf(opts, bufnr)
end

---@return number
---@param opts Opts
---@param bufnr number?
function M.compile_new_vsplit(opts, bufnr)
	opts.type = "terminal"
	return M.new_vsplit(opts, bufnr)
end

---@return number
---@param opts Opts
---@param bufnr number?
function M.compile_new_hsplit(opts, bufnr)
	opts.type = "terminal"
	return M.new_hsplit(opts, bufnr)
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
