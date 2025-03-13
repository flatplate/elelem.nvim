-- Test file for the replace tool in cli.lua
package.path = './lua/?.lua;' .. package.path
local test_utils = require("test.test_utils")
test_utils.init_vim_mock()

-- Mock file system operations
_G.io = {
  open = function(file, mode) 
    return {
      write = function(self, content) 
        _G.written_content = content
      end,
      close = function() end
    }
  end
}

_G.written_content = nil

-- Mock vim.fn functions
_G.vim.fn.readfile = function(path)
  if path == "/test/file.lua" then
    return {
      "local function test()",
      "  return false",
      "end",
      "",
      "local other_function = function()",
      "  print(\"test\")",
      "end"
    }
  end
  return {}
end

_G.vim.fn.confirm = function()
  return 1 -- Always confirm (Yes)
end

-- Mock other required modules
package.loaded["llm_search.highlights"] = {
  generate_diff = function(old, new) 
    return "DIFF:\n" .. old .. "\n" .. new
  end
}

-- Add additional vim utilities needed by the code
_G.vim.list_slice = function(list, start, finish)
  local result = {}
  finish = finish or #list
  for i = start, finish do
    table.insert(result, list[i])
  end
  return result
end

-- Mock LLM search IO utils
package.loaded["llm_search.io_utils"] = {
  execute_command = function(command, timeout, callback)
    callback(nil, "Command output", "")
  end
}

-- Additional mocks for buffer and window operations
_G.vim.api.nvim_create_buf = function() return 5 end
_G.vim.api.nvim_buf_set_option = function() end
_G.vim.api.nvim_buf_set_lines = function() end
_G.vim.api.nvim_get_option = function() return 100 end
_G.vim.api.nvim_open_win = function() return 10 end
_G.vim.api.nvim_win_set_option = function() end
_G.vim.api.nvim_win_close = function() end
_G.vim.api.nvim_echo = function() end

-- Load the module under test
local cli_tools = require("llm_search.tools.cli")

-- Test functions
local function test_normalize_whitespace()
  -- Extract the normalize_whitespace function from the replace handler
  -- We need to recreate it here for testing
  local function normalize_whitespace(str)
    -- Replace tabs and multiple spaces with a single space, but keep newlines
    local normalized = str:gsub("[ \t]+", " ")
    -- Trim spaces at the beginning and end of each line
    normalized = normalized:gsub("\n[ \t]+", "\n")
    normalized = normalized:gsub("[ \t]+\n", "\n")
    -- Trim leading/trailing spaces
    normalized = normalized:gsub("^[ \t]+", ""):gsub("[ \t]+$", "")
    return normalized
  end
  
  -- Test cases
  local test_cases = {
    {
      input = "  test  with  spaces  ",
      expected = "test with spaces",
      name = "Basic space normalization"
    },
    {
      input = "test\twith\ttabs",
      expected = "test with tabs",
      name = "Tab normalization"
    },
    {
      input = "  line1  \n  line2  \n  line3  ",
      expected = "line1\nline2\nline3",
      name = "Multiple line trim"
    },
    {
      input = "function() {\n    return true;\n}",
      expected = "function() {\nreturn true;\n}",
      name = "Code indentation"
    },
    {
      input = "  \t  mixed   \t spaces \t  and \t tabs  \t  ",
      expected = "mixed spaces and tabs",
      name = "Mixed spaces and tabs"
    }
  }
  
  -- Run tests
  for _, test_case in ipairs(test_cases) do
    local result = normalize_whitespace(test_case.input)
    test_utils.assert_equals(
      test_case.expected, 
      result, 
      "Normalize whitespace: " .. test_case.name
    )
  end
  
  print("All normalize_whitespace tests passed!")
end

local function test_line_range_replacement()
  -- Create a callback to collect results
  local result_data = nil
  local callback = function(data)
    result_data = data
  end
  
  -- Mock scheduled function calls
  local scheduled_fns = {}
  _G.vim.schedule = function(fn)
    table.insert(scheduled_fns, fn)
  end
  
  -- Test replace_by_lines
  local replace_lines_args = {
    files = {
      {
        path = "/test/file.lua",
        start_line = 2,
        end_line = 2,
        new_content = "  return true"
      }
    }
  }
  
  -- Trigger the handler
  cli_tools.replace_by_lines.handler(replace_lines_args, callback)
  
  -- Execute all scheduled functions
  for _, fn in ipairs(scheduled_fns) do
    fn()
  end
  
  -- Check if file was written with correct content
  test_utils.assert_not_nil(_G.written_content, "File should have been written")
  
  local expected_content = "local function test()\n  return true\nend\n\nlocal other_function = function()\n  print(\"test\")\nend"
  test_utils.assert_equals(expected_content, _G.written_content, "File content mismatch")
  
  -- Check the result message
  test_utils.assert_not_nil(result_data, "Callback should have been called")
  assert(result_data:match("✅"), "Result should indicate success")
  
  print("Line range replacement test passed!")
end

local function test_line_range_edge_cases()
  -- Create a callback to collect results
  local result_data = nil
  local callback = function(data)
    result_data = data
  end
  
  -- Mock scheduled function calls
  local scheduled_fns = {}
  _G.vim.schedule = function(fn)
    table.insert(scheduled_fns, fn)
  end
  
  -- Test replace with invalid line range
  local invalid_args = {
    files = {
      {
        path = "/test/file.lua",
        start_line = 100, -- Past end of file
        end_line = 101,
        new_content = "  return true"
      }
    }
  }
  
  -- Trigger the handler
  cli_tools.replace_by_lines.handler(invalid_args, callback)
  
  -- Execute all scheduled functions
  for _, fn in ipairs(scheduled_fns) do
    fn()
  end
  
  -- Check the result message
  test_utils.assert_not_nil(result_data, "Callback should have been called")
  assert(result_data:match("Error"), "Result should indicate error with line numbers")
  
  print("Line range edge case test passed!")
end

local function test_real_world_typescript_case()
  -- This test case is based on a real example where the model was trying to add
  -- a deleteLesson method to a TypeScript class

  -- The normalize_whitespace function extracted from the tool
  local function normalize_whitespace(str)
    -- Replace tabs and multiple spaces with a single space, but keep newlines
    local normalized = str:gsub("[ \t]+", " ")
    -- Trim spaces at the beginning and end of each line
    normalized = normalized:gsub("\n[ \t]+", "\n")
    normalized = normalized:gsub("[ \t]+\n", "\n")
    -- Trim leading/trailing spaces
    normalized = normalized:gsub("^[ \t]+", ""):gsub("[ \t]+$", "")
    return normalized
  end

  -- The original file content (simplified)
  local original_content = [[import type { Flashcard, Lesson, Section } from '@lets-chat/core';
import { authTable, type DynamoTable } from '../../utils/dynamo';

export class LessonStore {
  table: DynamoTable;

  constructor(table: DynamoTable) {
    this.table = table;
  }

  getKeys(userId: string, lessonId: string) {
    return {
      pk: `users/${userId}`,
      sk: `lessons/${lessonId}`,
    };
  }

  async putLesson(lesson: Lesson) {
    const { pk, sk } = this.getKeys(lesson.userId, lesson.id);
    await this.table.putItem(pk, sk, lesson);
  }

  async getLesson(userId: string, lessonId: string) {
    const { pk, sk } = this.getKeys(userId, lessonId);
    return this.table.getItem(pk, sk);
  }

  async listLessons(userId: string): Promise<Lesson[]> {
    const pk = `users/${userId}`;
    const items = await this.table.query(pk, 'lessons');
    return items as Lesson[];
  }
}

export const lessonStore = new LessonStore(authTable);]]

  -- The fragment the model is trying to match (with different indentation)
  local search_fragment = [[  async listLessons(userId: string): Promise<Lesson[]> {
      const pk = `users/${userId}`;
      const items = await this.table.query(pk, 'lessons');
      return items as Lesson[];
  }]]

  -- The replacement with the new method
  local replacement = [[  async listLessons(userId: string): Promise<Lesson[]> {
    const pk = `users/${userId}`;
    const items = await this.table.query(pk, 'lessons');
    return items as Lesson[];
  }

  async deleteLesson(userId: string, lessonId: string) {
    const { pk, sk } = this.getKeys(userId, lessonId);
    await this.table.deleteItem(pk, sk);
  }]]

  -- Check for direct match first
  local exact_match = original_content:find(search_fragment, 1, true)
  
  if exact_match then
    print("Direct match found at position:", exact_match)
  else
    print("No direct match found")
    
    -- Try with whitespace normalization
    local normalized_content = normalize_whitespace(original_content)
    local normalized_search = normalize_whitespace(search_fragment)
    
    local normalized_match = normalized_content:find(normalized_search, 1, true)
    if normalized_match then
      print("Match found after whitespace normalization at position:", normalized_match)
      
      -- If we found a match, we'd need to extract the original text with the right line count
      local original_lines = vim.split(original_content, "\n")
      local search_lines = vim.split(search_fragment, "\n")
      local search_line_count = #search_lines
      
      -- Find which line the match starts on
      local start_line_index = 1
      local current_pos = 1
      local normalized_content_lines = vim.split(normalized_content, "\n")
      
      for i, line in ipairs(normalized_content_lines) do
        local line_length = #line + 1 -- +1 for newline
        if current_pos + line_length > normalized_match then
          start_line_index = i
          break
        end
        current_pos = current_pos + line_length
      end
      
      -- Extract the matching lines from the original content
      local extracted_original = {}
      for i = 0, search_line_count - 1 do
        if start_line_index + i <= #original_lines then
          table.insert(extracted_original, original_lines[start_line_index + i])
        end
      end
      
      local extracted_text = table.concat(extracted_original, "\n")
      print("\nExtracted original text based on normalized match:")
      print(extracted_text)
      
      -- Check if the extraction is useful for replacement
      print("\nOriginal text to replace (showing each character code):")
      for i = 1, #extracted_text do
        local c = extracted_text:sub(i,i)
        print(string.format("Char %d: '%s' (code: %d)", i, c, string.byte(c)))
      end
      
      -- Check if there are invisible/special characters
      print("\nOriginal content (showing specific portion):")
      local match_position = original_content:find(extracted_text, 1, true)
      if match_position then
        local start = math.max(1, match_position - 5)
        local finish = math.min(match_position + #extracted_text + 5, #original_content)
        local context = original_content:sub(start, finish)
        
        for i = 1, #context do
          local c = context:sub(i,i)
          if i == 6 then -- This should be where the match starts (assuming we went back 5 chars)
            print(string.format("Char %d: '%s' (code: %d) <-- MATCH START", i, c, string.byte(c)))
          else
            print(string.format("Char %d: '%s' (code: %d)", i, c, string.byte(c)))
          end
        end
      else
        print("Could not find exact position for detailed analysis")
      end
      
      -- Let's try a different approach with explicit string manipulation
      local match_position = original_content:find(extracted_text, 1, true)
      if match_position then
        print("\nFound match at position:", match_position)
        
        -- Create new content by explicit concatenation
        local before = original_content:sub(1, match_position - 1)
        local after = original_content:sub(match_position + #extracted_text)
        local new_content = before .. replacement .. after
        
        print("Original length:", #original_content)
        print("New content length:", #new_content)
        print("Difference:", #new_content - #original_content)
        
        if new_content:find("deleteLesson") then
          print("✅ Manual replacement worked correctly")
        else
          print("❌ Even manual replacement failed")
        end
      else
        print("❌ Failed to find the match position for manual replacement")
      end
    else
      print("No match even after whitespace normalization")
    end
  end
end

local function test_replace_with_diff()
  -- Create a callback to collect results
  local result_data = nil
  local callback = function(data)
    result_data = data
  end
  
  -- Mock scheduled function calls
  local scheduled_fns = {}
  _G.vim.schedule = function(fn)
    table.insert(scheduled_fns, fn)
  end
  
  -- Mock buffer and window functions
  _G.vim.api.nvim_create_buf = function() return 100 end
  _G.vim.api.nvim_buf_set_option = function() end
  _G.vim.api.nvim_buf_set_lines = function() end
  _G.vim.api.nvim_get_option = function() return 100 end
  _G.vim.api.nvim_open_win = function() return 200 end
  _G.vim.api.nvim_win_set_option = function() end
  _G.vim.api.nvim_buf_set_keymap = function() end
  _G.vim.fn.fnamemodify = function(path, mod) return path end

  -- Mock confirm to always return "Yes"
  _G.vim.fn.confirm = function()
    return 1 -- Always confirm (Yes)
  end
  
  -- Mock the window validity check
  _G.vim.api.nvim_win_is_valid = function() return true end
  
  -- Mock window close
  _G.vim.api.nvim_win_close = function() end
  
  -- Mock the file reading/writing for a specific test file
  local test_file_content = "function test() {\n  return false;\n}"
  local io_open_original = io.open
  io.open = function(path, mode)
    if path == "/test/replace_diff.js" then
      if mode == "r" then
        return {
          read = function() return test_file_content end,
          close = function() end
        }
      elseif mode == "w" then
        return {
          write = function(self, content) 
            _G.written_content = content
          end,
          close = function() end
        }
      end
    end
    return io_open_original(path, mode)
  end
  
  -- Test the replace_with_diff tool
  local args = {
    file_path = "/test/replace_diff.js",
    content = "function test() {\n  return true;\n}",
    show_diff = true
  }
  
  -- Trigger the handler
  cli_tools.replace_with_diff.handler(args, callback)
  
  -- Execute all scheduled functions
  for _, fn in ipairs(scheduled_fns) do
    fn()
  end
  
  -- Check if file was written with correct content
  test_utils.assert_not_nil(_G.written_content, "File should have been written")
  test_utils.assert_equals("function test() {\n  return true;\n}", _G.written_content, "File content mismatch")
  
  -- Check the result message
  test_utils.assert_not_nil(result_data, "Callback should have been called")
  assert(result_data:match("✅"), "Result should indicate success")
  
  -- Restore mocks
  io.open = io_open_original
  
  print("Replace with diff test passed!")
end

local function test_file_replace_tool()
  -- Create a callback to collect results
  local result_data = nil
  local callback = function(data)
    result_data = data
  end
  
  -- Mock scheduled function calls
  local scheduled_fns = {}
  _G.vim.schedule = function(fn)
    table.insert(scheduled_fns, fn)
  end
  
  -- Mock the global elelem_options
  _G.elelem_options = { show_diffs = true }
  
  -- Load test tools that contains the file_replace tool
  local test_tools = require("llm_search.tools.test")
  
  -- Mock the file reading/writing for a specific test file
  local test_file_content = "function test() {\n  return false;\n}"
  local io_open_original = io.open
  io.open = function(path, mode)
    if path == "/test/file_replace_test.js" then
      if mode == "r" then
        return {
          read = function() return test_file_content end,
          close = function() end
        }
      elseif mode == "w" then
        return {
          write = function(self, content) 
            _G.written_content = content
          end,
          close = function() end
        }
      end
    end
    return io_open_original(path, mode)
  end
  
  -- Test the file_replace tool
  local args = {
    file_path = "/test/file_replace_test.js",
    content = "function test() {\n  return true;\n}",
  }
  
  -- Trigger the handler
  test_tools.file_replace.handler(args, callback)
  
  -- Execute all scheduled functions
  for _, fn in ipairs(scheduled_fns) do
    fn()
  end
  
  -- Check if file was written with correct content
  test_utils.assert_not_nil(_G.written_content, "File should have been written")
  test_utils.assert_equals("function test() {\n  return true;\n}", _G.written_content, "File content mismatch")
  
  -- Check the result message
  test_utils.assert_not_nil(result_data, "Callback should have been called")
  assert(result_data:match("✅"), "Result should indicate success")
  
  -- Restore mocks
  io.open = io_open_original
  _G.elelem_options = nil
  
  print("File replace tool test passed!")
end

-- Run all tests
test_normalize_whitespace()
test_line_range_replacement()
test_line_range_edge_cases()
test_real_world_typescript_case()
test_replace_with_diff()
test_file_replace_tool()

print("All replace tool tests passed!")