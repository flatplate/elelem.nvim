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

M.search_quickfix = function(custom_prompt, model)
  model = model or DEFAULT_MODEL
  generic_llm_search(
    context_suppliers.from_quickfix_list,
    query_suppliers.from_popup,
    output_handler.to_result_buffer,
    custom_prompt,
    model
  )
end

M.append_llm_output = function(custom_prompt, model)
  model = model or DEFAULT_APPEND_MODEL
  generic_llm_search(
    context_suppliers.from_whole_file_with_append_marker,
    query_suppliers.from_popup,
    output_handler.append_to_file,
    custom_prompt,
    model
  )
end

M.search_current_file = function(custom_prompt, model)
  model = model or DEFAULT_MODEL
  generic_llm_search(
    context_suppliers.from_whole_file,
    query_suppliers.from_popup,
    output_handler.to_result_buffer,
    custom_prompt,
    model
  )
end

M.search_visual_selection = function(custom_prompt, model)
  model = model or DEFAULT_MODEL
  generic_llm_search(
    context_suppliers.from_visual_selection,
    query_suppliers.from_popup,
    output_handler.to_result_buffer,
    custom_prompt,
    model
  )
end

M.append_llm_output_visual = function(custom_prompt, model)
  model = model or DEFAULT_APPEND_MODEL
  generic_llm_search(
    context_suppliers.from_visual_selection,
    query_suppliers.from_popup,
    output_handler.append_to_file,
    custom_prompt,
    model
  )
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
