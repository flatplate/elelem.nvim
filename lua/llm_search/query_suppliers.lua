-- query_input.lua
local M = {}
local io_utils = require("llm_search.io_utils")

function M.from_popup(callback)
  io_utils.popup_input(function(query)
    if query and query ~= "" then
      callback(query)
    else
      print("No query entered")
    end
  end)
end

function M.empty_supplier(callback)
  callback("")
end

-- Placeholder for potential future input methods
-- function M.from_command_line(callback)
--   -- Implementation
-- end

-- function M.from_buffer(callback)
--   -- Implementation
-- end

return M
