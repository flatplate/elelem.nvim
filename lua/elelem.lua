local M = {}
local models = require("llm_search.models")
local providers = require("llm_search.providers")
local llm_utils = require("llm_search.llm_utils")

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

local function generic_llm_search(context_func, input_func, output_func, custom_prompt, model)
  local context = context_func()
  input_func(function(query)
    if query and query ~= "" then
      -- Show loading message
      output_func.init(model, context)

      llm_utils.stream_llm(context, query, custom_prompt, output_func.handle, model)
    else
      print("No query entered")
    end
  end)
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

local function build_action(action, default_model)
  return function(custom_prompt, model)
    generic_llm_search(
      action.context_supplier,
      action.query_supplier,
      action.output_handler,
      custom_prompt,
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
}

M.search_quickfix = build_action(search_quickfix_action, DEFAULT_MODEL)
M.append_llm_output = build_action(append_llm_output_action, DEFAULT_APPEND_MODEL)
M.search_current_file = build_action(search_current_file_action, DEFAULT_MODEL)
M.search_visual_selection = build_action(search_visual_selection_action, DEFAULT_MODEL)
M.append_llm_output_visual = build_action(append_llm_output_visual_action, DEFAULT_APPEND_MODEL)

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
