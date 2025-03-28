local M = {}
local models = require("llm_search.models")
local providers = require("llm_search.providers")
local context_picker = require("llm_search.context_picker")
local context = require("llm_search.context")
local io_utils = require("llm_search.io_utils")
local highlights = require("llm_search.highlights")
local tools = require("llm_search.tools")

M.context_picker = context_picker.context_picker
M.context = context

-- Configuration
local DEFAULT_MODEL = models.deepseek
local DEFAULT_APPEND_MODEL = models.deepseek_base
local CONTEXT_LINES = 16 -- Number of lines to extract before and after each quickfix item

local plenary_path = require("plenary.path")
local log_path = plenary_path:new(vim.fn.stdpath("cache")):joinpath("quickfix_llm_search.log")

local context_suppliers = require("llm_search.context_suppliers")
local query_suppliers = require("llm_search.query_suppliers")
local output_handler = require("llm_search.output_handler")

IS_DEBUG = false

local function generic_llm_search(messages_supplier, output_func, model)
	messages_supplier(function(messages)
		if messages and #messages > 0 then
			-- Show loading message
			output_func.init(model, messages) -- Assume first message is context

			local current_tools = nil
			if model.supports_tool_use then
				current_tools = tools.get_used_tools_list()
			end
			model.provider.stream(model, messages, output_func.handle, output_func.finish, current_tools)
		else
			print("No messages supplied")
		end
	end)
end

local function combine_context_and_input(opts)
	local context_func = opts.context_supplier
	local input_func = opts.query_supplier
	local system_message = opts.system_message
		or "You are a helpful assistant. You help the user in their IDE, by answering questions from the user based on the context."

	return function(callback)
		local ctx = context_func()
		input_func(function(query)
			local messages = {
				{ role = "system", content = system_message },
			}
			if query and query ~= "" then
				table.insert(messages, { role = "user", content = query })
			end
			for i = 1, #ctx do
				table.insert(messages, ctx[i])
			end
			callback(messages)
		end)
	end
end

local search_quickfix_action = {
	title = "Search quickfix list",
	context_supplier = context_suppliers.from_quickfix_list,
	query_supplier = query_suppliers.from_popup,
	output_handler = output_handler.to_result_buffer,
}

local search_current_file_action = {
	title = "Search current file",
	context_supplier = context_suppliers.from_whole_file,
	query_supplier = query_suppliers.from_popup,
	output_handler = output_handler.to_result_buffer,
}

local search_visual_selection_action = {
	title = "Search visual selection",
	context_supplier = context_suppliers.from_visual_selection,
	query_supplier = query_suppliers.from_popup,
	output_handler = output_handler.to_result_buffer,
}

local append_llm_output_action = {
	title = "Append LLM output to file",
	context_supplier = context_suppliers.from_whole_file_with_append_marker,
	query_supplier = query_suppliers.from_popup,
	output_handler = output_handler.append_to_file,
}

local append_llm_output_visual_action = {
	title = "Append LLM output to file",
	context_supplier = context_suppliers.from_visual_selection,
	query_supplier = query_suppliers.from_popup,
	output_handler = output_handler.append_to_file,
}

-- Just ask normally with empty context, shows in result buffer
local ask_llm = {
	title = "Ask LLM",
	context_supplier = context_suppliers.empty_context,
	query_supplier = query_suppliers.from_popup,
	output_handler = output_handler.to_result_buffer,
}

local ask_chat = {
	title = "Ask LLM in chat",
	context_supplier = context_suppliers.combine_providers({
		context_suppliers.from_context,
		context_suppliers.from_chat,
	}),
	query_supplier = query_suppliers.empty_supplier,
	output_handler = output_handler.append_to_chat_buffer,
}

local fix_diagnostic = {
	title = "Fix diagnostic",
	context_supplier = context_suppliers.from_lsp_diagnostics,
	query_supplier = query_suppliers.empty_supplier,
	output_handler = output_handler.to_result_buffer,
}

local ask_next_change = {
	title = "Ask LLM for next change",
	context_supplier = context_suppliers.from_undo,
	query_supplier = query_suppliers.empty_supplier,
	output_handler = output_handler.to_result_buffer,
}

local function init_new_chat()
	-- Clear the chat buffer
	-- ctx is a table from file name - line to the stirng
	-- list the context file - line as the output if it is not empty
	local ctx = context.get_context_summary()
	io_utils.clear_result_buffer()
	if ctx and ctx ~= "" then
		io_utils.append_to_result_buffer("[Comment]: This chat currently has the following context: \n\n")
		io_utils.append_to_result_buffer(ctx)
		io_utils.append_to_result_buffer("\n\n")
	end
	io_utils.append_to_result_buffer("[User]: ")
end

local function build_action(action, default_model)
	return function(custom_prompt, model)
		generic_llm_search(
			combine_context_and_input({
				context_supplier = action.context_supplier,
				query_supplier = action.query_supplier,
				system_message = custom_prompt,
			}),
			action.output_handler,
			model or default_model
		)
	end
end

M.actions = {
	search_quickfix = search_quickfix_action,
	search_current_file = search_current_file_action,
	search_visual_selection = search_visual_selection_action,
	append_llm_output = append_llm_output_action,
	append_llm_output_visual = append_llm_output_visual_action,
	ask_llm = ask_llm,
	ask_chat = ask_chat,
	ask_next_change = ask_next_change,
	fix_diagnostic = fix_diagnostic,
}

M.search_quickfix = build_action(search_quickfix_action, DEFAULT_MODEL)
M.append_llm_output = build_action(append_llm_output_action, DEFAULT_APPEND_MODEL)
M.search_current_file = build_action(search_current_file_action, DEFAULT_MODEL)
M.search_visual_selection = build_action(search_visual_selection_action, DEFAULT_MODEL)
M.append_llm_output_visual = build_action(append_llm_output_visual_action, DEFAULT_APPEND_MODEL)
M.ask_llm = build_action(ask_llm, DEFAULT_MODEL)
M.ask_chat = build_action(ask_chat, DEFAULT_MODEL)
M.ask_next_change = build_action(ask_next_change, DEFAULT_MODEL)
M.init_new_chat = init_new_chat
M.apply_changes = highlights.apply_diff_changes
-- Expose tool management functions at the top level
M.telescope_add_tool = tools.telescope_add_tool
M.telescope_remove_tool = tools.telescope_remove_tool
M.get_available_tools_list = tools.get_available_tools_list
M.debug_print_tools = tools.debug_print_tools
M.add_tool = tools.add_tool
M.remove_tool = tools.remove_tool
M.get_used_tools = tools.get_used_tools_list

M.generic_action = function(opts)
	local action = {
		context_supplier = opts.context_supplier or context_suppliers.empty_context,
		query_supplier = opts.query_supplier or query_suppliers.from_popup,
		output_handler = opts.output_handler or output_handler.to_result_buffer,
		model_provider = opts.model_provider or function(cb)
			cb(DEFAULT_MODEL)
		end,
	}

	return function(custom_prompt)
		action.model_provider(function(model)
			generic_llm_search(
				combine_context_and_input({
					context_supplier = action.context_supplier,
					query_suppliers = action.query_supplier,
					system_message = custom_prompt,
				}),
				action.output_handler,
				model
			)
		end)
	end
end

M.set_debug = function(debug)
	IS_DEBUG = debug
end

M.toggle_debug = function()
	IS_DEBUG = not IS_DEBUG
end

function M.open_log_file()
	vim.cmd("edit " .. log_path.filename)
end

M.setup = function(opts)
	opts = opts or {}
	config = opts
	highlights.setup()
	providers.set_config(opts)
	
	-- Store user options
	_G.elelem_options = {
		show_diffs = opts.show_diffs == nil and true or opts.show_diffs, -- Default to true
	}
	
	-- Initialize default tools if specified in config
	if opts.tools and opts.tools.default_tools and type(opts.tools.default_tools) == "table" then
		vim.schedule(function()
			-- Allow a short delay for all plugin components to initialize
			for _, tool_name in ipairs(opts.tools.default_tools) do
				tools.add_tool(tool_name)
				if opts.tools.verbose then
					print("elelem.nvim: Added default tool: " .. tool_name)
				end
			end
			
			-- Show a summary of enabled tools if verbose
			if opts.tools.verbose then
				local enabled_tools = vim.tbl_keys(tools.used_tools)
				if #enabled_tools > 0 then
					print("elelem.nvim: Enabled tools: " .. table.concat(enabled_tools, ", "))
				end
			end
		end)
	end
end

M.models = models
return M
