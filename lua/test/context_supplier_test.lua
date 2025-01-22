-- Mock vim API functions similar to highlights_spec.lua
_G.vim = {
  split = function(str, sep, opts)
    if sep == "\n" then
      local parts = {}
      local start = 1
      local plain = opts and opts.plain

      while true do
        local pos = string.find(str, "\n", start, plain)
        if not pos then
          table.insert(parts, string.sub(str, start))
          break
        end
        table.insert(parts, string.sub(str, start, pos - 1))
        start = pos + 1
      end
      return parts
    end
    -- Fall back to simple pattern matching for other cases
    local parts = {}
    for part in string.gmatch(str, "[^" .. sep .. "]+") do
      table.insert(parts, part)
    end
    return parts
  end,
  api = {
    nvim_buf_get_lines = function()
      return {}
    end,
    nvim_get_current_buf = function()
      return 1
    end,
    nvim_win_get_cursor = function()
      return { 1, 0 }
    end,
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
          type = "E",
        },
        {
          bufnr = 1,
          lnum = 5,
          col = 1,
          text = "Warning: unused variable 'bar'",
          type = "W",
        },
      }
    end,
  },
  notify = function(message, level)
    print(string.format("NOTIFY [%s]: %s", level, message))
  end,
  log = {
    levels = {
      WARN = "WARN",
      ERROR = "ERROR",
    },
  },
}

package.loaded["llm_search.io_utils"] = {
  read_result_buffer = function()
    -- This will be overridden in individual tests
    return ""
  end,
}

-- Mock the file_utils module
package.loaded["llm_search.file_utils"] = {
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
  end,
}

local context_suppliers = require("llm_search.context_suppliers")

local function test_quickfix_list_provider()
  -- Test with mock quickfix items
  local messages = context_suppliers.from_quickfix_list()

  -- Verify we got exactly one message
  assert(#messages == 1, string.format("Expected 1 message, got %d", #messages))

  -- Verify the message role
  assert(messages[1].role == "system", string.format("Expected role 'system', got '%s'", messages[1].role))

  -- Verify the message content contains our mock quickfix items
  assert(
  messages[1].content:match("Line 2: Error: undefined variable 'foo'"),
  "Message should contain the first quickfix item"
  )
  assert(
  messages[1].content:match("Line 5: Warning: unused variable 'bar'"),
  "Message should contain the second quickfix item"
  )
end

local function test_empty_quickfix_list()
  -- Override the getqflist function to return empty list
  local original_getqflist = vim.fn.getqflist
  vim.fn.getqflist = function()
    return {}
  end

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
  assert(
  messages[1].content:match("Entire file content:\nmock file content"),
  "Message should contain the file content with proper prefix"
  )
end

local function test_whole_file_with_append_marker()
  local messages = context_suppliers.from_whole_file_with_append_marker()

  assert(#messages == 1, "Should return exactly one message")
  assert(messages[1].role == "user", "Message role should be 'user'")
  assert(
  messages[1].content:match("File content with append marker:\nmock file content with <|>marker"),
  "Message should contain the file content with append marker"
  )
end

-- Run the tests
test_quickfix_list_provider()
test_empty_quickfix_list()
test_whole_file_provider()
test_whole_file_with_append_marker()
print("All context supplier tests passed!")

local function test_from_chat_empty()
  package.loaded["llm_search.io_utils"].read_result_buffer = function()
    return ""
  end

  local messages = context_suppliers.from_chat()
  assert(#messages == 0, "Should return an empty list of messages, returned " .. #messages)
end

local function test_from_chat_basic_conversation()
  package.loaded["llm_search.io_utils"].read_result_buffer = function()
    return [[
    [User]: Hello
    multi
    line
    [Model]: Hi there
    [User]: How are you?
    [Model]: I'm doing well, thanks!
    also multi
    line]]
  end

  local messages = context_suppliers.from_chat()
  local err_msg = string.format("Message count mismatch:\nExpected: 4\nReceived: %d", #messages)
  assert(#messages == 4, err_msg)

  -- First message checks
  err_msg = string.format("First message role mismatch:\nExpected: user\nReceived: %s", messages[1].role)
  assert(messages[1].role == "user", err_msg)

  err_msg = string.format("First message content mismatch:\nReceived: %s\nExpected: Hello", messages[1].content)
  assert(messages[1].content == "Hello\nmulti\nline", err_msg)

  -- Second message checks
  err_msg = string.format("Second message role mismatch:\nExpected: assistant\nReceived: %s", messages[2].role)
  assert(messages[2].role == "assistant", err_msg)

  err_msg = string.format("Second message content mismatch:\nExpected: Hi there\nReceived: %s", messages[2].content)
  assert(messages[2].content == "Hi there", err_msg)

  -- Third and Fourth message role checks
  err_msg = string.format("Third message role mismatch:\nExpected: user\nReceived: %s", messages[3].role)
  assert(messages[3].role == "user", err_msg)

  err_msg = string.format("Fourth message role mismatch:\nExpected: assistant\nReceived: %s", messages[4].role)
  assert(messages[4].role == "assistant", err_msg)

  err_msg = string.format(
  "Fourth message content mismatch:\nExpected: I'm doing well, thanks!\nalso multi\nline\nReceived: %s",
  messages[4].content
  )
  assert(messages[4].content == "I'm doing well, thanks!\nalso multi\nline", err_msg)
end

local function test_from_chat_with_comments()
  package.loaded["llm_search.io_utils"].read_result_buffer = function()
    return [[
    [User]: Hello
    some
    multi
    line
    [Comment]: This is a comment
    [Model]: Hi there
    Multi line
    [User]: How are you?]]
  end

  local messages = context_suppliers.from_chat()
  local err_msg =
  string.format("Message count mismatch (comments should be ignored):\nExpected: 3\nReceived: %d", #messages)
  assert(#messages == 3, err_msg)

  err_msg = string.format("First message role mismatch:\nExpected: user\nReceived: %s", messages[1].role)
  assert(messages[1].role == "user", err_msg)

  err_msg = string.format("Second message role mismatch:\nExpected: assistant\nReceived: %s", messages[2].role)
  assert(messages[2].role == "assistant", err_msg)

  err_msg = string.format("Third message role mismatch:\nExpected: user\nReceived: %s", messages[3].role)
  assert(messages[3].role == "user", err_msg)
end

local function test_from_chat_git_diff_command()
  package.loaded["llm_search.io_utils"].read_result_buffer = function()
    return [[
    [User]: /git-diff Show me the changes
    [Model]: Here are the changes:]]
  end

  local original_git_diff = context_suppliers.from_git_diff
  context_suppliers.from_git_diff = function()
    return { {
      role = "user",
      content = "Git diff content here",
    } }
  end

  local messages = context_suppliers.from_chat()
  local err_msg = string.format("Message count mismatch:\nExpected: >= 2\nReceived: %d", #messages)
  assert(#messages >= 2, err_msg)

  err_msg =
  string.format("Git diff content mismatch:\nExpected: Git diff content here\nReceived: %s", messages[1].content)
  assert(messages[1].content == "Git diff content here", err_msg)

  context_suppliers.from_git_diff = original_git_diff
end

-- Run the tests
print("Running chat context supplier tests...")
test_from_chat_empty()
print("Empty chat context test passed!")
test_from_chat_basic_conversation()
print("Basic chat context test passed!")
test_from_chat_with_comments()
print("Chat context with comments test passed!")
test_from_chat_git_diff_command()
print("Chat context with git diff command test passed!")
print("All chat context supplier tests passed!")
