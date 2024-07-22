local M = {}
local models = require("llm_search.models")
local file_utils = require("llm_search.file_utils")
local io_utils = require("llm_search.io_utils")
local providers = require("llm_search.providers")
local llm_utils = require("llm_search.llm_utils")

-- Configuration
local DEFAULT_MODEL = models.deepseek
local DEFAULT_APPEND_MODEL = models.deepseek_base
local CONTEXT_LINES = 8 -- Number of lines to extract before and after each quickfix item

local plenary_path = require('plenary.path')
local log_path = plenary_path:new(vim.fn.stdpath('cache')):joinpath('quickfix_llm_search.log')

local log = require("plenary.log").new({
  plugin = "quickfix_llm_search",
  level = "debug",
  use_console = false,
  highlights = false,
  file_path = log_path.filename,
})

-- Main function to search quickfix list
function M.search_quickfix(custom_prompt, model)
  model = model or DEFAULT_MODEL
  io_utils.popup_input(function(query)
    if query and query ~= "" then
      local qf_list = vim.fn.getqflist()

      if #qf_list == 0 then
        vim.notify("Quickfix list is empty", vim.log.levels.WARN)
        return
      end

      local context = file_utils.consolidate_context(qf_list, CONTEXT_LINES)
      if context == "" then
        vim.notify("No valid context found in quickfix list", vim.log.levels.WARN)
        return
      end

      -- Show a "loading" message
      io_utils.display_in_result_buffer("Loading...\nPlease wait while the LLM processes your query.")

      llm_utils.query_llm(context, query, custom_prompt, function(result)
        io_utils.display_in_result_buffer(result)
      end, false, model)
    else
      print("No query entered")
    end
  end)
end

local function write_string_at_cursor(str, no_join_undo)
  vim.schedule(function()
    local current_window = vim.api.nvim_get_current_win()
    local cursor_position = vim.api.nvim_win_get_cursor(current_window)
    local row, col = cursor_position[1], cursor_position[2]

    local lines = vim.split(str, '\n')

    if not no_join_undo then
      vim.cmd("undojoin")
    end
    vim.api.nvim_put(lines, 'c', true, true)

    local num_lines = #lines
    local last_line_length = #lines[num_lines]
    vim.api.nvim_win_set_cursor(current_window, { row + num_lines - 1, col + last_line_length })
  end)
end

function M.append_llm_output(custom_prompt, model)
  model = model or DEFAULT_APPEND_MODEL
  log.debug("Starting append_llm_output function")
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)

  local row, col = cursor[1], cursor[2]

  local context = file_utils.get_current_file_content_with_append_marker(bufnr, row, col)

  write_string_at_cursor("", true)
  io_utils.popup_input(function(query)
    if query and query ~= "" then
      llm_utils.stream_llm(context, query, custom_prompt, write_string_at_cursor, model)
    else
      log.warn("No query entered")
      vim.notify("No query entered", vim.log.levels.INFO)
    end
  end)
end


-- Function to search the current file
function M.search_current_file(custom_prompt, model, debug)
  io_utils.popup_input(function(query)
    if query and query ~= "" then
      local context = file_utils.get_current_file_content()

      -- Show a "loading" message
      io_utils.display_in_result_buffer("Loading...\nPlease wait while the LLM processes your query.")

      if debug then
        local debug_content = "System Message:\n" ..
            (custom_prompt or "") .. "\n\nContext:\n" .. context .. "\n\nQuery: " .. query
        io_utils.display_in_result_buffer(debug_content)
        return
      end

      llm_utils.query_llm(context, query, custom_prompt, function(result)
        io_utils.display_in_result_buffer(result)
      end, false, model)
    else
      print("No query entered")
    end
  end)
end

function M.search_visual_selection(custom_prompt, model, debug)
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[2] - 1, end_pos[2], false)

  if #lines == 1 then
    lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
  else
    lines[1] = lines[1]:sub(start_pos[3])
    lines[#lines] = lines[#lines]:sub(1, end_pos[3])
  end

  local context = table.concat(lines, "\n")

  io_utils.popup_input(function(query)
    if query and query ~= "" then
      io_utils.display_in_result_buffer("Loading...\nPlease wait while the LLM processes your query.")

      if debug then
        local debug_content = "System Message:\n" ..
            (custom_prompt or "") .. "\n\nContext:\n" .. context .. "\n\nQuery: " .. query
        io_utils.display_in_result_buffer(debug_content)
        return
      end

      llm_utils.query_llm(context, query, custom_prompt, function(result)
        io_utils.display_in_result_buffer(result)
      end, false, model)
    else
      print("No query entered")
    end
  end)
end

function M.append_llm_output_visual(custom_prompt, model)
  model = model or DEFAULT_APPEND_MODEL
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_pos[2] - 1, end_pos[2], false)

  if #lines == 1 then
    lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
  else
    lines[1] = lines[1]:sub(start_pos[3])
    lines[#lines] = lines[#lines]:sub(1, end_pos[3])
  end

  local context = table.concat(lines, "\n")

  write_string_at_cursor("", true)
  io_utils.popup_input(function(query)
    if query and query ~= "" then
      llm_utils.stream_llm(context, query, custom_prompt, write_string_at_cursor, model)
    else
      log.warn("No query entered")
      vim.notify("No query entered", vim.log.levels.INFO)
    end
  end)
end

function M.open_log_file()
  vim.cmd('edit ' .. log_path.filename)
end

M.setup = function(opts)
  M.config = opts or {}
  providers.set_config(M.config)
end

M.models = models

return M
