-- context_gatherer.lua
local M = {}
local file_utils = require("llm_search.file_utils")
local io_utils = require("llm_search.io_utils")
local diff = require("llm_search.diff")

local CONTEXT_LINES = 8

-- Helper function to create a message
local function create_message(role, content)
	return {
		role = role,
		content = content,
	}
end

function M.from_undo()
	return { create_message("user", "Changes:\n" .. diff.get_last_change_diff()) }
end

function M.from_visual_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local bufnr = vim.api.nvim_get_current_buf()
	local mode = vim.fn.visualmode()
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[2] - 1, end_pos[2], false)

	local content
	if mode == "V" then
		content = table.concat(lines, "\n")
	else
		if #lines == 1 then
			lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
		else
			lines[1] = lines[1]:sub(start_pos[3])
			lines[#lines] = lines[#lines]:sub(1, end_pos[3])
		end
		content = table.concat(lines, "\n")
	end

	return create_message("user", "Selected text:\n" .. content)
end

function M.combine_providers(providers)
	return function()
		local combined_messages = {}
		for _, provider in ipairs(providers) do
			local messages = provider()
			for _, message in ipairs(messages) do
				table.insert(combined_messages, message)
			end
		end
		return combined_messages
	end
end

function M.from_git_diff()
	-- Execute git diff with maximum context lines
	local handle = io.popen("git diff --unified=9999 2>&1")
	if not handle then
		vim.notify("Failed to execute git diff", vim.log.levels.ERROR)
		return { create_message("user", "") }
	end
	local diff_output = handle:read("*a")
	handle:close()

	-- Handle empty output case
	if diff_output == "" then
		vim.notify("No git changes detected", vim.log.levels.WARN)
		return { create_message("user", "") }
	end

	return { create_message("user", "Git diff with full context:\n" .. diff_output) }
end

-- Reads the chat buffer
-- Splits the chat into messages
-- A model message starts with \n\n[Model]:
-- A user message starts with \n\n[User]:
-- An ignored/comment message starts with \n\n[Comment]:
function M.from_chat()
	local chat_buffer_content = io_utils.read_result_buffer()

	-- Check if chat_lines is nil or empty
	if not chat_buffer_content or chat_buffer_content == "" then
		vim.notify("No chat found", vim.log.levels.WARN)
		return {}
	end

	local messages = {}
	local current_message = {
		role = nil,
		content = {},
	}

	local function insert_into_messages()
		local content = table.concat(current_message.content, "\n")
		if current_message.role == "user" then
			-- Handle commands
			if content:match("/git%-diff") then
				-- Remove the command from the content
				content = (content:gsub("/git%-diff%s*", ""))

				-- Get git diff messages and prepend them
				local git_diff_messages = M.from_git_diff()
				for i = #git_diff_messages, 1, -1 do
					table.insert(messages, 1, git_diff_messages[i])
				end
			end
		end
		if current_message.role then
			table.insert(messages, create_message(current_message.role, content))
			current_message = {
				role = nil,
				content = {},
			}
		end
	end

	-- Split the string into lines
	local lines = vim.split(chat_buffer_content, "\n", { plain = true })
	for _, line in ipairs(lines) do
		if line:match("^%[Model%]:") then
			insert_into_messages()
			-- Start new model message
			current_message = {
				role = "assistant",
				content = { (line:gsub("^%[Model%]:%s*", "")) },
			}
		elseif line:match("^%[User%]:") then
			insert_into_messages()
			-- Start new user message

			current_message = {
				role = "user",
				content = { (line:gsub("^%[User%]:%s*", "")) },
			}
		elseif line:match("^%[Comment%]:") then
			insert_into_messages()
			-- Reset current message when encountering a comment
			current_message = {
				role = nil,
				content = {},
			}
		elseif current_message.role then
			-- Append line to current message if it exists
			table.insert(current_message.content, line)
		end
	end

	insert_into_messages()

	return messages
end

function M.from_context()
	local context = require("llm_search.context").get_context_string()
	if context == nil then
		vim.notify("No context found", vim.log.levels.WARN)
		return {}
	end
	if context == "" then
		return {}
	end
	return { create_message("user", "Context from codebase:\n" .. context) }
end

function M.from_quickfix_list()
	local qf_list = vim.fn.getqflist()

	if #qf_list == 0 then
		vim.notify("Quickfix list is empty", vim.log.levels.WARN)
		return { create_message("user", "") }
	end

	local context = file_utils.consolidate_context(qf_list, CONTEXT_LINES)
	if context == "" then
		vim.notify("No valid context found in quickfix list", vim.log.levels.WARN)
		return { create_message("user", "") }
	end

	return { create_message("system", "Context from quickfix list:\n" .. context) }
end

function M.from_whole_file()
	local content = file_utils.get_current_file_content()
	return { create_message("user", "Entire file content:\n" .. content) }
end

function M.from_whole_file_with_append_marker()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1], cursor[2]

	local content = file_utils.get_current_file_content_with_append_marker(bufnr, row, col)
	return { create_message("user", "File content with append marker:\n" .. content) }
end

-- Gets the LSP diagnostics for the current buffer
function M.from_lsp_diagnostics()
	local bufnr = vim.api.nvim_get_current_buf()
	local diagnostics = vim.diagnostic.get(bufnr)

	if #diagnostics == 0 then
		vim.notify("No LSP diagnostics found", vim.log.levels.WARN)
		return { create_message("user", "") }
	end

	-- Sort diagnostics by line number
	table.sort(diagnostics, function(a, b)
		return a.lnum < b.lnum
	end)

	-- Format diagnostics into a readable string
	local lines = {}
	local filename = vim.fn.expand("%:p")
	table.insert(lines, string.format("LSP diagnostics for %s:", filename))

	for _, diag in ipairs(diagnostics) do
		local severity = vim.diagnostic.severity[diag.severity] or "UNKNOWN"
		local line = diag.lnum + 1 -- Convert to 1-based line numbers
		local col = diag.col + 1 -- Convert to 1-based column numbers

		-- Get the line content for context
		local line_content = vim.api.nvim_buf_get_lines(bufnr, diag.lnum, diag.lnum + 1, false)[1] or ""

		table.insert(
			lines,
			string.format("[%s] Line %d, Col %d: %s\nCode: %s", severity, line, col, diag.message, line_content)
		)
	end

	-- Get some surrounding context for each diagnostic
	local context_lines = {}
	local prev_range_end = -1

	for _, diag in ipairs(diagnostics) do
		local start_line = math.max(0, diag.lnum - CONTEXT_LINES)
		local end_line = math.min(vim.api.nvim_buf_line_count(bufnr) - 1, diag.lnum + CONTEXT_LINES)

		-- Avoid duplicating context if diagnostics are close together
		if start_line > prev_range_end then
			if prev_range_end ~= -1 then
				table.insert(context_lines, "...")
			end

			local context = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
			for i, line in ipairs(context) do
				local line_num = start_line + i
				table.insert(context_lines, string.format("%d: %s", line_num + 1, line))
			end

			prev_range_end = end_line
		end
	end

	if #context_lines > 0 then
		table.insert(lines, "\nContext:")
		vim.list_extend(lines, context_lines)
	end

	return { create_message("user", table.concat(lines, "\n")) }
end

function M.empty_context()
	return { create_message("user", "") }
end

return M
