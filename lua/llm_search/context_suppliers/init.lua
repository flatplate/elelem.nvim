local M = {}

local message_utils = require("llm_search.context_suppliers.message_utils")
local file_utils = require("llm_search.file_utils")

local selection_supplier = require("llm_search.context_suppliers.selection_supplier")
local file_supplier = require("llm_search.context_suppliers.file_supplier")
local diagnostics_supplier = require("llm_search.context_suppliers.diagnostics_supplier")
local git_supplier = require("llm_search.context_suppliers.git_supplier")
local chat_parser = require("llm_search.context_suppliers.chat_parser")

local CONTEXT_LINES = 8

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

function M.from_context()
	local context = require("llm_search.context").get_context_string()
	if context == nil then
		vim.notify("No context found", vim.log.levels.WARN)
		return {}
	end
	return { message_utils.create_message("user", "Context from codebase:\n" .. context) }
end

function M.from_quickfix_list()
	local qf_list = vim.fn.getqflist()

	if #qf_list == 0 then
		vim.notify("Quickfix list is empty", vim.log.levels.WARN)
		return { message_utils.create_message("user", "") }
	end

	local context = file_utils.consolidate_context(qf_list, CONTEXT_LINES)
	if context == "" then
		vim.notify("No valid context found in quickfix list", vim.log.levels.WARN)
		return { message_utils.create_message("user", "") }
	end

	return { message_utils.create_message("system", "Context from quickfix list:\n" .. context) }
end

function M.empty_context()
	return { message_utils.create_message("user", "") }
end

-- Re-export functions from other modules
M.from_undo = selection_supplier.from_undo
M.from_visual_selection = selection_supplier.from_visual_selection
M.from_whole_file = file_supplier.from_whole_file
M.from_whole_file_with_append_marker = file_supplier.from_whole_file_with_append_marker
M.from_lsp_diagnostics = diagnostics_supplier.from_lsp_diagnostics
M.from_git_diff = git_supplier.from_git_diff
M.from_chat = chat_parser.from_chat

return M
