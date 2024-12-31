local M = {}
local models = require("llm_search.models")
local providers = require("llm_search.providers")
local context_picker = require("llm_search.context_picker")
local context = require("llm_search.context")
local io_utils = require("llm_search.io_utils")

M.context_picker = context_picker.context_picker
M.context = context

-- Configuration
local DEFAULT_MODEL = models.deepseek
local DEFAULT_APPEND_MODEL = models.deepseek_base
local CONTEXT_LINES = 8 -- Number of lines to extract before and after each quickfix item

local config            -- Config from the setup function
local plenary_path = require('plenary.path')
local log_path = plenary_path:new(vim.fn.stdpath('cache')):joinpath('quickfix_llm_search.log')

local context_suppliers = require("llm_search.context_suppliers")
local query_suppliers = require("llm_search.query_suppliers")
local output_handler = require("llm_search.output_handler")

IS_DEBUG = false


local function generic_llm_search(messages_supplier, output_func, model)
  messages_supplier(function(messages)
    if messages and #messages > 0 then
      -- Show loading message
      output_func.init(model, messages) -- Assume first message is context

      model.provider.stream(model, messages, output_func.handle, output_func.finish)
    else
      print("No messages supplied")
    end
  end)
end

local function combine_context_and_input(opts)
  local context_func = opts.context_supplier
  local input_func = opts.query_supplier
  local system_message = opts.system_message or
      "You are a helpful assistant. You help the user in their IDE, by answering questions from the user based on the context."

  return function(callback)
    local ctx = context_func()
    input_func(function(query)
      local messages = {
        { role = "system", content = system_message },
      }
      if query and query ~= "" then
        messages[#messages + 1] = { role = "user", content = query }
      end
      for i = 1, #ctx do
        messages[#messages + i] = ctx[i]
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
  context_supplier = context_suppliers.combine_providers({ context_suppliers.from_context, context_suppliers.from_chat }),
  query_supplier = query_suppliers.empty_supplier,
  output_handler = output_handler.append_to_chat_buffer,
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
      combine_context_and_input {
        context_supplier = action.context_supplier,
        query_supplier = action.query_supplier,
        system_message = custom_prompt
      },
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
}

M.search_quickfix = build_action(search_quickfix_action, DEFAULT_MODEL)
M.append_llm_output = build_action(append_llm_output_action, DEFAULT_APPEND_MODEL)
M.search_current_file = build_action(search_current_file_action, DEFAULT_MODEL)
M.search_visual_selection = build_action(search_visual_selection_action, DEFAULT_MODEL)
M.append_llm_output_visual = build_action(append_llm_output_visual_action, DEFAULT_APPEND_MODEL)
M.ask_llm = build_action(ask_llm, DEFAULT_MODEL)
M.ask_chat = build_action(ask_chat, DEFAULT_MODEL)
M.init_new_chat = init_new_chat

M.generic_action = function(opts)
  local action = {
    context_supplier = opts.context_supplier or context_suppliers.empty_context,
    query_supplier = opts.query_supplier or query_suppliers.from_popup,
    output_handler = opts.output_handler or output_handler.to_result_buffer,
    model_provider = opts.model_provider or function(cb) cb(DEFAULT_MODEL) end
  }

  return function(custom_prompt)
    action.model_provider(function(model)
      generic_llm_search(
        combine_context_and_input {
          context_supplier = action.context_supplier,
          query_suppliers = action.query_supplier,
          system_message = custom_prompt
        },
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
  vim.cmd('edit ' .. log_path.filename)
end

M.setup = function(opts)
  config = opts
  providers.set_config(opts)
end

M.models = models

return M
