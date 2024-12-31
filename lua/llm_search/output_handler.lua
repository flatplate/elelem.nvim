local M = {}
local io_utils = require("llm_search.io_utils")

M.to_result_buffer = {
  init = function(model, context)
    io_utils.clear_result_buffer()
    local output = "Model: " .. model.name .. "\n\n"
    if IS_DEBUG then
      output = output .. "Context:\n" .. context .. "\n\n"
    end
    io_utils.display_in_result_buffer(output)
  end,

  handle = function(str)
    io_utils.append_to_result_buffer(str)
  end
}

M.append_to_chat_buffer = {
  init = function(model, context)
    local output = "\n\n[Model]: "
    io_utils.append_to_result_buffer(output)
  end,

  handle = function(str)
    io_utils.append_to_result_buffer(str)
  end,

  finish = function()
    io_utils.append_to_result_buffer("\n\n[User]:")
  end
}

M.append_to_file = {
  init = function(model, context)
    -- No initialization needed for appending to file
  end,

  handle = function(str)
    vim.schedule(function()
      local current_window = vim.api.nvim_get_current_win()
      local cursor_position = vim.api.nvim_win_get_cursor(current_window)
      local row, col = cursor_position[1], cursor_position[2]

      local lines = vim.split(str, '\n')

      vim.cmd("undojoin")
      vim.api.nvim_put(lines, 'c', true, true)

      local num_lines = #lines
      local last_line_length = #lines[num_lines]
      vim.api.nvim_win_set_cursor(current_window, { row + num_lines - 1, col + last_line_length })
    end)
  end
}

return M
