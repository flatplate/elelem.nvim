-- Function to create a popup input
local function popup_input(callback)
	local Input = require("nui.input")
	local event = require("nui.utils.autocmd").event

	local input = Input({
		position = "50%",
		size = {
			width = 60,
		},
		border = {
			style = "rounded",
			text = {
				top = "Enter your query",
				top_align = "center",
			},
		},
		win_options = {
			winhighlight = "Normal:Normal,FloatBorder:Normal",
		},
	}, {
		prompt = "> ",
		default_value = "",
		on_close = function()
			print("Input cancelled")
		end,
		on_submit = function(value)
			callback(value)
		end,
	})

	input:mount()

	input:on(event.BufLeave, function()
		input:unmount()
	end)
end

-- Global variable to store the buffer number
local result_bufnr = nil

-- Function to get or create the result buffer
local function get_result_buffer()
	if result_bufnr and vim.api.nvim_buf_is_valid(result_bufnr) then
		return result_bufnr
	end

	-- Check if a buffer with the name already exists
	local existing_bufnr = vim.fn.bufnr("LLM Search Results")
	if existing_bufnr ~= -1 and vim.api.nvim_buf_is_valid(existing_bufnr) then
		result_bufnr = existing_bufnr
		return result_bufnr
	end

	-- Create a new buffer
	result_bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(result_bufnr, "buftype", "nofile")
	vim.api.nvim_buf_set_option(result_bufnr, "bufhidden", "hide")
	vim.api.nvim_buf_set_option(result_bufnr, "swapfile", false)
	-- set filetype to markdown
	vim.api.nvim_buf_set_option(result_bufnr, "filetype", "markdown")

	-- Only set the name if it's a new buffer
	vim.api.nvim_buf_set_name(result_bufnr, "LLM Search Results")

	return result_bufnr
end

-- Function to read the content of the result buffer
local function read_result_buffer()
	local bufnr = get_result_buffer()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return nil
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	return table.concat(lines, "\n")
end

-- Function to display content in the result buffer
local function display_in_result_buffer(content, filetype)
	local bufnr = get_result_buffer()

	-- Find or create a window for the buffer
	local winid = vim.fn.bufwinid(bufnr)
	if winid == -1 then
		vim.cmd("vsplit")
		winid = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(winid, bufnr)
	else
		vim.api.nvim_set_current_win(winid)
	end

	-- Clear the buffer and set its content
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))

	-- Set the filetype (markdown by default)
	vim.api.nvim_buf_set_option(bufnr, "filetype", filetype or "markdown")

	-- Set 'wrap' option for the window
	vim.api.nvim_win_set_option(winid, "wrap", true)

	-- Move cursor to the top of the buffer
	vim.api.nvim_win_set_cursor(winid, { 1, 0 })
	
	return bufnr, winid
end

local function append_to_result_buffer(content)
	vim.schedule(function()
		local bufnr = get_result_buffer()

		local winid = vim.fn.bufwinid(bufnr)
		if winid == -1 then
			-- Create a new window for the buffer if it's not visible
			local current_win = vim.api.nvim_get_current_win()
			vim.cmd("vsplit")
			winid = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_option(winid, "wrap", true)
			vim.api.nvim_win_set_buf(winid, bufnr)
			vim.api.nvim_set_current_win(current_win) -- Return focus to the original window
		end

		vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
		local last_line = vim.api.nvim_buf_line_count(bufnr)
		local last_line_content = vim.api.nvim_buf_get_lines(bufnr, last_line - 1, last_line, false)[1] or ""

		local content_lines = vim.split(content, "\n")
		if last_line_content ~= "" then
			content_lines[1] = last_line_content .. content_lines[1]
		end
		vim.api.nvim_buf_set_lines(bufnr, last_line - 1, last_line, false, content_lines)

		vim.api.nvim_buf_set_option(bufnr, "modified", false)
	end)
end

local function clear_result_buffer()
	local bufnr = get_result_buffer()
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
end

-- Function to execute shell commands asynchronously
local function execute_command(command, timeout, callback)
	timeout = timeout or 10000 -- Default 10s timeout
	
	local stdout = ""
	local stderr = ""
	local handle = nil
	local timer = nil
	
	-- Start a timer for timeout
	if timeout > 0 then
		timer = vim.uv.new_timer()
		timer:start(timeout, 0, function()
			if handle then
				handle:kill(15) -- SIGTERM
				callback("Command timed out after " .. timeout .. "ms", stdout, stderr)
			end
			if timer then
				timer:stop()
				timer:close()
			end
		end)
	end
	
	local function on_read(err, data)
		if data then
			return data
		end
		return ""
	end
	
	-- Create pipes for stdout and stderr
	local stdout_pipe = vim.uv.new_pipe(false)
	local stderr_pipe = vim.uv.new_pipe(false)
	
	handle = vim.uv.spawn("sh", {
		args = { "-c", command },
		stdio = { nil, stdout_pipe, stderr_pipe }
	}, function(code, signal)
		if timer then
			timer:stop()
			timer:close()
		end
		
		-- Make sure to close the pipes
		stdout_pipe:close()
		stderr_pipe:close()
			
		if code ~= 0 then
			callback("Command exited with code " .. code .. " (signal: " .. signal .. ")", stdout, stderr)
		else
			callback(nil, stdout, stderr)
		end
	end)
	
	if not handle then
		if timer then
			timer:stop()
			timer:close()
		end
		
		-- Close pipes if spawn failed
		stdout_pipe:close()
		stderr_pipe:close()
		
		return callback("Failed to start command: " .. command)
	end
	
	-- Capture stdout
	vim.uv.read_start(stdout_pipe, function(err, data)
		local output = on_read(err, data)
		if output and output ~= "" then
			stdout = stdout .. output
		end
	end)
	
	-- Capture stderr
	vim.uv.read_start(stderr_pipe, function(err, data)
		local output = on_read(err, data)
		if output and output ~= "" then
			stderr = stderr .. output
		end
	end)
end

local M = {
	popup_input = popup_input,
	get_result_buffer = get_result_buffer,
	display_in_result_buffer = display_in_result_buffer,
	append_to_result_buffer = append_to_result_buffer,
	clear_result_buffer = clear_result_buffer,
	read_result_buffer = read_result_buffer,
	execute_command = execute_command,
}

return M
