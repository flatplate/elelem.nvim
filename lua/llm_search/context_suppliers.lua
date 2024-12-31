-- context_gatherer.lua
local M = {}
local file_utils = require("llm_search.file_utils")
local io_utils = require("llm_search.io_utils")

local CONTEXT_LINES = 8

-- Helper function to create a message
local function create_message(role, content)
    return {
        role = role,
        content = content
    }
end

function M.from_visual_selection()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local bufnr = vim.api.nvim_get_current_buf()
    local mode = vim.fn.visualmode()
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[2] - 1, end_pos[2], false)

    local content
    if mode == 'V' then
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

    return { create_message("user", "Selected text:\n" .. content) }
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

-- Reads the chat buffer
-- Splits the chat into messages
-- A model message starts with \n\n[Model]:
-- A user message starts with \n\n[User]:
-- An ignored/comment message starts with \n\n[Comment]:
function M.from_chat()
    local chat_lines = io_utils.read_result_buffer()

    -- Check if chat_lines is nil or empty
    if not chat_lines or chat_lines == "" then
        vim.notify("No chat found", vim.log.levels.WARN)
        return create_message("user", "")
    end

    local messages = {}
    local current_message = {
        role = nil,
        content = {}
    }

    -- Split the string into lines
    for line in chat_lines:gmatch("[^\r\n]+") do
        if line:match("^%[Model%]:") then
            -- If there was a previous message, add it to messages
            if current_message.role then
                table.insert(messages, create_message(
                    current_message.role,
                    table.concat(current_message.content, "\n")
                ))
            end
            -- Start new model message
            current_message = {
                role = "assistant",
                content = { line:gsub("^%[Model%]:%s*", "") }
            }
        elseif line:match("^%[User%]:") then
            -- If there was a previous message, add it to messages
            if current_message.role then
                table.insert(messages, create_message(
                    current_message.role,
                    table.concat(current_message.content, "\n")
                ))
            end
            -- Start new user message
            current_message = {
                role = "user",
                content = { line:gsub("^%[User%]:%s*", "") }
            }
        elseif line:match("^%[Comment%]:") then
            -- If there was a previous message, add it to messages
            if current_message.role then
                table.insert(messages, create_message(
                    current_message.role,
                    table.concat(current_message.content, "\n")
                ))
            end
            -- Reset current message when encountering a comment
            current_message = {
                role = nil,
                content = {}
            }
        elseif current_message.role then
            -- Append line to current message if it exists
            table.insert(current_message.content, line)
        end
    end

    -- Add the last message if it exists
    if current_message.role then
        table.insert(messages, create_message(
            current_message.role,
            table.concat(current_message.content, "\n")
        ))
    end

    return messages
end

function M.from_context()
    local context = require("llm_search.context").get_context_string()
    if context == nil then
        vim.notify("No context found", vim.log.levels.WARN)
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

function M.empty_context()
    return { create_message("user", "") }
end

return M
