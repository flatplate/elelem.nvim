-- Mock vim API functions
_G.vim = {
  api = {
    nvim_buf_get_lines = function() end,
    nvim_create_namespace = function() return 1 end,
    nvim_set_hl = function() end,
    nvim_buf_set_lines = function() end,
    nvim_buf_del_extmark = function() end,
    nvim_buf_set_extmark = function() return 1 end,
    nvim_create_autocmd = function() end,
    nvim_create_user_command = function() end,
    nvim_buf_is_valid = function() return true end -- Add this line
  },
  fn = {
    bufnr = function(name)
      if name == "LLM Search Results" then
        return 2
      end
      return 1
    end,
    escape = function(str) return str end,
  },
  regex = function() return { match_str = function() return true end } end,
  notify = function(message) print("NOTIFY: " .. message) end,
  log = { levels = { ERROR = 1 } },
  trim = function(str)
    if str == nil then
      return nil
    end
    return str:match("^%s*(.-)%s*$")
  end,
  list_slice = function(list, start, finish)
    local new_list = {}
    for i = start, finish do
      table.insert(new_list, list[i])
    end
    return new_list
  end,
  list_extend = function(...)
    local new_list = {}
    for _, list in ipairs({ ... }) do
      for _, item in ipairs(list) do
        table.insert(new_list, item)
      end
    end
    return new_list
  end,
  inspect = function(t)
    local str = "{"
    for k, v in pairs(t) do
      v = v
      if type(v) == "string" then
        v = "\"" .. v .. "\""
      elseif type(v) == "table" then
        v = vim.inspect(v)
      end
      str = str .. k .. " = " .. v .. ", "
    end
    return str .. "}"
  end
}

local highlights = require('llm_search.highlights')
highlights.setup()

local function test_parse_diff()
  -- Test case 1: Basic diff with file paths and @@ markers
  local test_diff = [[
```diff
+++ b/path/to/test.lua
@@ @@
 local function test()
-  print("old")
+  print("new")
 end
```
]]
  local lines = {}
  for line in test_diff:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  print("Lines: ", table.concat(lines, '\n'))

  -- Mock the result buffer getter
  package.loaded['llm_search.io_utils'] = {
    get_result_buffer = function() return 3 end
  }

  -- Mock buffer lines
  _G.vim.api.nvim_buf_get_lines = function(bufnr)
    if bufnr == 2 then
      return lines
    elseif bufnr == 1 then
      return {
        "local function test()",
        "  print(\"old\")",
        "end"
      }
    end
  end

  local called_with = nil
  _G.vim.api.nvim_buf_set_lines = function(_, line_num, _, _, new_lines)
    called_with = {
      line_num = line_num,
      new_lines = new_lines
    }
  end

  -- Call the function
  highlights.apply_changes()

  -- Assert the changes were applied correctly
  assert(called_with ~= nil, "Changes should have been applied")
  assert(called_with.line_num == 2, "Change should be applied to line 2, instead got " .. called_with.line_num)
  assert(called_with.new_lines[1] == '  print("new")', "New line content should match")
end

local function test_parse_complex_diff()
  -- Test case 2: Multiple hunks with file paths and @@ markers
  local test_diff = [[
```diff
+++ b/path/to/test.lua
@@ @@
 local function test1()
-  return false
+  return true
 end

@@ @@
 local function test2()
-  print("hello")
+  print("world")
 end
```
]]

  local lines = {}
  for line in test_diff:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  -- Mock buffer lines
  _G.vim.api.nvim_buf_get_lines = function()
    return lines
  end

  local changes = {}
  _G.vim.api.nvim_buf_set_lines = function(_, line_num, _, _, new_lines)
    table.insert(changes, {
      line_num = line_num,
      new_lines = new_lines
    })
  end

  -- Call the function
  highlights.apply_changes()

  -- Assert the changes were applied correctly
  assert(#changes == 2, "Should have applied 2 changes, instead got " .. #changes)
  assert(changes[1].line_num == 2, "First change should be at line 2, instead got")  -- Adjusted for first @@ line
  assert(changes[2].line_num == 6, "Second change should be at line 6") -- Adjusted for second @@ line
  assert(changes[1].new_lines[1] == '  return true', "First change should match")
  assert(changes[2].new_lines[1] == '  print("world")', "Second change should match")
end

local function test_process_hunk()
  -- Test case 1: Simple hunk with context and changes
  local test_hunk = {
    "@@ -1,5 +1,5 @@",
    " local function example()",
    "-  return false",
    "+  return true",
    " end",
    " ",
    " local other_line"
  }

  local removal_lines, addition_lines, preceding_context, following_context = highlights.process_hunk(test_hunk)

  for _, line in ipairs(preceding_context) do
    print(" " .. line.content)
  end
  for _, line in ipairs(removal_lines) do
    print("-" .. line.content)
  end
  for _, line in ipairs(addition_lines) do
    print("+" .. line.content)
  end
  for _, line in ipairs(following_context) do
    print(" " .. line.content)
  end

  -- Assert removal lines
  assert(#removal_lines == 1, "Should have one removal line, instead got " .. #removal_lines)
  assert(removal_lines[1].content == "return false", "Removal content should match")
  assert(removal_lines[1].full == "  return false",
    string.format("Removal full line should match\n- %s\n+ %s", "  return false", removal_lines[1].full))

  -- Assert addition lines
  assert(#addition_lines == 1, "Should have one addition line")
  assert(addition_lines[1].content == "return true", "Addition content should match")
  assert(addition_lines[1].full == "  return true", "Addition full line should match")

  -- Assert preceding context
  assert(#preceding_context == 1, string.format("Should have one preceding context line, got %d", #preceding_context))
  assert(preceding_context[1].content == "local function example()", "Preceding context should match")

  -- Assert following context
  if #following_context < 3 then
    assert(false)
  end
  assert(following_context[1].content == "end", "First following context line should match")
  assert(following_context[2].content == "",
    string.format("Second following context line should match:\n-%s\n+%s", following_context[2].content,
      "local other_line"))
  assert(following_context[3].content == "local other_line",
    string.format("Third following context line should match:\n-%s\n+%s", following_context[3].content,
      "local other_line"))
  assert(#following_context == 3,
    string.format("Should have two following context lines instead got %d", #following_context))

  -- Test case 2: Multiple changes with interleaved context
  local test_hunk_2 = {
    "@@ -1,6 +1,6 @@",
    " def function():",
    "-  x = 1",
    "+  x = 2",
    " ",
    "-  y = 2",
    "+  y = 3",
    " end"
  }

  local removal_lines_2, addition_lines_2, preceding_context_2, following_context_2 = highlights.process_hunk(
    test_hunk_2)

  -- Print all the context lines and changes
  for _, line in ipairs(preceding_context_2) do
    print(" " .. line.content)
  end
  for _, line in ipairs(removal_lines_2) do
    print("-" .. line.content)
  end
  for _, line in ipairs(addition_lines_2) do
    print("+" .. line.content)
  end
  for _, line in ipairs(following_context_2) do
    print(" " .. line.content)
  end

  -- Assert removal lines
  assert(#removal_lines_2 == 3, "Should have three removal lines (including context)")
  assert(removal_lines_2[1].content == "x = 1", "First removal should match")
  assert(removal_lines_2[3].content == "y = 2", "Second removal should match")

  -- Assert addition lines
  assert(#addition_lines_2 == 3, "Should have three addition lines (including context)")
  assert(addition_lines_2[1].content == "x = 2", "First addition should match")
  assert(addition_lines_2[3].content == "y = 3", "Second addition should match")

  -- Assert contexts
  assert(#preceding_context_2 == 1, "Should have one preceding context line, instead got " .. #preceding_context_2)
  assert(#following_context_2 == 1, "Should have one following context line, instead got " .. #following_context_2)

  print("All process_hunk tests passed!")
end
local function test_parse_diff_hunks()
  -- Test case for highlight changes diff
  local test_diff = [[
```diff
--- //Users/ural/Projects/elelem.nvim/lua/llm_search/highlights.lua
+++ //Users/ural/Projects/elelem.nvim/lua/llm_search/highlights.lua
@@ @@
 -- Setup highlight groups
 local function setup_highlights()
   vim.api.nvim_set_hl(1, "InlineSuggestionRemove", { fg = "#F47067", strikethrough = true })
   vim.api.nvim_set_hl(1, "InlineSuggestionAdd", { fg = "#4EC994", italic = true })
-  vim.api.nvim_set_hl(0, "InlineSuggestionUnchanged", { fg = "#808080" })
+  vim.api.nvim_set_hl(1, "InlineSuggestionUnchanged", { fg = "#808080" })
 end
```
]]

  local lines = {}
  for line in test_diff:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  local edits = highlights.parse_diff_hunks(lines)

  -- Assertions
  assert(#edits == 1, "Should have parsed one edit, isntead got " .. #edits)
  assert(edits[1].path == "//Users/ural/Projects/elelem.nvim/lua/llm_search/highlights.lua",
    "Path should match")

  local hunk = edits[1].hunk
  assert(#hunk == 8, string.format("Hunk should have 7 lines, but got %d lines. Hunk content:\n%s",
    #hunk, table.concat(hunk, '\n')))
  assert(hunk[1]:match("@@ @@"), "First line should be the hunk header")
  assert(hunk[6] == "-  vim.api.nvim_set_hl(0, \"InlineSuggestionUnchanged\", { fg = \"#808080\" })",
    "Should contain the removed line")
  assert(hunk[7] == "+  vim.api.nvim_set_hl(1, \"InlineSuggestionUnchanged\", { fg = \"#808080\" })",
    "Should contain the added line")
end

local function test_find_context_match()
  -- Test case 1: Single match scenario
  local test_buffer_content = {
    "local function example()",
    "  return false",
    "end",
    "",
    "local other_line"
  }

  -- Mock buffer lines getter
  _G.vim.api.nvim_buf_get_lines = function()
    return test_buffer_content
  end

  local preceding_context = {
    { content = "local function example()" }
  }
  local removal_lines = {
    { content = "return false" }
  }
  local following_context = {
    { content = "end" },
    { content = "" },
    { content = "local other_line" }
  }

  local match_line = highlights.find_context_match(1, preceding_context, removal_lines, following_context)
  assert(match_line == 2, string.format("Should find match at line 1, instead got %s", tostring(match_line)))

  -- Test case 2: No match scenario
  local no_match_context = {
    { content = "function does_not_exist()" }
  }
  local no_match = highlights.find_context_match(1, no_match_context, removal_lines, following_context)
  assert(no_match == nil, "Should return nil when no match is found")

  -- Test case 3: Multiple matches scenario (should return nil)
  local duplicate_content = {
    "local function example()",
    "  return false",
    "end",
    "",
    "local function example()",
    "  return false",
    "end"
  }

  _G.vim.api.nvim_buf_get_lines = function()
    return duplicate_content
  end

  local multiple_match = highlights.find_context_match(1, preceding_context, removal_lines, following_context)
  assert(multiple_match == nil, "Should return nil when multiple matches are found")

  -- Test case 4: Empty context
  local empty_match = highlights.find_context_match(1, {}, {}, {})
  assert(empty_match == nil, "Should return nil with empty context")

  print("All find_context_match tests passed!")
end
-- Run the testst
test_find_context_match()
test_process_hunk()
test_parse_diff_hunks()
test_parse_diff()
test_parse_complex_diff()
print("All tests passed!")
