-- context_gatherer.lua
local M = {}
local file_utils = require("llm_search.file_utils")

local CONTEXT_LINES = 8 -- Number of lines to extract before and after each quickfix item

function M.from_visual_selection()
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

  return table.concat(lines, "\n")
end

function M.from_quickfix_list()
  local qf_list = vim.fn.getqflist()

  if #qf_list == 0 then
    vim.notify("Quickfix list is empty", vim.log.levels.WARN)
    return ""
  end

  local context = file_utils.consolidate_context(qf_list, CONTEXT_LINES)
  if context == "" then
    vim.notify("No valid context found in quickfix list", vim.log.levels.WARN)
    return ""
  end

  return context
end

function M.from_whole_file()
  return file_utils.get_current_file_content()
end

function M.from_whole_file_with_append_marker()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1], cursor[2]

  return file_utils.get_current_file_content_with_append_marker(bufnr, row, col)
end

return M
