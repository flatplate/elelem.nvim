-- Mock vim API functions similar to highlights_spec.lua
_G.vim = {
  api = {
    nvim_buf_get_lines = function() return {} end,
    nvim_get_current_buf = function() return 1 end,
    nvim_win_get_cursor = function() return {1, 0} end,
    nvim_create_namespace = function() return 1 end,
  },
  fn = {
    getqflist = function()
      -- Return mock quickfix items
      return {
        {
          bufnr = 1,
          lnum = 2,
          col = 1,
          text = "Error: undefined variable 'foo'",
          type = "E"
        },
        {
          bufnr = 1,
          lnum = 5,
          col = 1,
          text = "Warning: unused variable 'bar'",
          type = "W"
        }
      }
    end
  },
  notify = function(message, level) 
    print(string.format("NOTIFY [%s]: %s", level, message))
  end,
  log = {
    levels = {
      WARN = "WARN",
      ERROR = "ERROR"
    }
  }
}

-- Mock the file_utils module
package.loaded['llm_search.file_utils'] = {
  consolidate_context = function(qf_list, context_lines)
    -- Mock implementation that returns a formatted string based on the quickfix items
    local result = ""
    for _, item in ipairs(qf_list) do
      result = result .. string.format("Line %d: %s\n", item.lnum, item.text)
    end
    return result
  end,
  get_current_file_content = function()
    return "mock file content"
  end,
  get_current_file_content_with_append_marker = function()
    return "mock file content with <|>marker"
  end
}

local context_suppliers = require('llm_search.context_suppliers')

local function test_quickfix_list_provider()
  -- Test with mock quickfix items
  local messages = context_suppliers.from_quickfix_list()
  
  -- Verify we got exactly one message
  assert(#messages == 1, string.format("Expected 1 message, got %d", #messages))
  
  -- Verify the message role
  assert(messages[1].role == "system", 
    string.format("Expected role 'system', got '%s'", messages[1].role))
  
  -- Verify the message content contains our mock quickfix items
  assert(messages[1].content:match("Line 2: Error: undefined variable 'foo'"),
    "Message should contain the first quickfix item")
  assert(messages[1].content:match("Line 5: Warning: unused variable 'bar'"),
    "Message should contain the second quickfix item")
end

local function test_empty_quickfix_list()
  -- Override the getqflist function to return empty list
  local original_getqflist = vim.fn.getqflist
  vim.fn.getqflist = function() return {} end
  
  local messages = context_suppliers.from_quickfix_list()
  
  -- Restore original function
  vim.fn.getqflist = original_getqflist
  
  -- Verify we got exactly one empty message
  assert(#messages == 1, "Should return one message even when quickfix list is empty")
  assert(messages[1].content == "", "Message content should be empty for empty quickfix list")
end

local function test_whole_file_provider()
  local messages = context_suppliers.from_whole_file()
  
  assert(#messages == 1, "Should return exactly one message")
  assert(messages[1].role == "user", "Message role should be 'user'")
  assert(messages[1].content:match("Entire file content:\nmock file content"),
    "Message should contain the file content with proper prefix")
end

local function test_whole_file_with_append_marker()
  local messages = context_suppliers.from_whole_file_with_append_marker()
  
  assert(#messages == 1, "Should return exactly one message")
  assert(messages[1].role == "user", "Message role should be 'user'")
  assert(messages[1].content:match("File content with append marker:\nmock file content with <|>marker"),
    "Message should contain the file content with append marker")
end

-- Run the tests
test_quickfix_list_provider()
test_empty_quickfix_list()
test_whole_file_provider()
test_whole_file_with_append_marker()
print("All context supplier tests passed!")
