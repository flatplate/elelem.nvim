local io_utils = require("llm_search.io_utils")

local M = {}

-- Create namespace for extmarks
local ns_id = vim.api.nvim_create_namespace("inline_suggestions")
local current_extmarks = {}

local function startswith(str, prefix)
  return string.sub(str, 1, #prefix) == prefix
end

-- Setup highlight grou
local function setup_highlights()
  vim.api.nvim_set_hl(1, "InlineSuggestionRemove", { fg = "#F47067", strikethrough = true })
  vim.api.nvim_set_hl(0, "InlineSuggestionAdd", { fg = "#4EC994", italic = true })
  vim.api.nvim_set_hl(0, "InlineSuggestionUnchanged", { fg = "#808080" })
end


-- Clear all suggestions
local function clear_suggestions()
  for _, id in ipairs(current_extmarks) do
    vim.api.nvim_buf_del_extmark(0, ns_id, id)
  end
  current_extmarks = {}
end

-- Find the longest common prefix of two strings
local function common_prefix(str1, str2)
  local i = 1
  while i <= #str1 and i <= #str2 and str1:sub(i, i) == str2:sub(i, i) do
    i = i + 1
  end
  return str1:sub(1, i - 1)
end

-- Find the longest common suffix of two strings after a given position
local function common_suffix(str1, str2, start1, start2)
  local i = 0
  while i < (#str1 - start1 + 1) and i < (#str2 - start2 + 1)
    and str1:sub(#str1 - i, #str1 - i) == str2:sub(#str2 - i, #str2 - i) do
    i = i + 1
  end
  return str1:sub(#str1 - i + 1)
end

function M.parse_diff_hunks(lines)
  local edits = {}
  local in_code_block = false
  local current_hunk = {}
  local current_path = nil
  local have_file_header = false

  for _, line in ipairs(lines) do
    if startswith(line, "```diff") then
      in_code_block = true
      have_file_header = false
      goto continue
    elseif line == "```" then
      -- Exit code block and save current hunk if not empty
      if #current_hunk > 0 then
        table.insert(edits, { path = current_path, hunk = current_hunk })
        current_hunk = {}
      end
      in_code_block = false
      goto continue
    end

    if in_code_block then
      -- Handle file headers (--- and +++ lines)
      if not have_file_header then
        if line:match("^%-%-%- ") then
          -- Skip the --- line
          goto continue
        elseif line:match("^%+%+%+ ") then
          current_path = line:sub(5):gsub("^%s*(.-)%s*$", "%1")
          have_file_header = true
          goto continue
        end
      end

      -- Add all other lines to the current hunk
      if #line > 0 then
        table.insert(current_hunk, line)
      end
    end
    ::continue::
  end

  -- Add final hunk if there is one
  if #current_hunk > 0 then
    table.insert(edits, { path = current_path, hunk = current_hunk })
  end

  return edits
end

-- Move hunk processing logic to a separate function
function M.process_hunk(hunk)
  local removal_lines = {}
  local addition_lines = {}
  local preceding_context = {}
  local following_context = {}
  local current_context = {}
  local changes_started = false

  local function start_changes()
    if not changes_started then
      preceding_context = vim.list_slice(current_context, 1, #current_context)
      current_context = {}
      changes_started = true
      return true
    elseif #current_context > 0 then
      -- Add the context lines to both removal and addition
      -- To make sure we have one continuous context block
      for _, context_line in ipairs(current_context) do
        table.insert(removal_lines, context_line)
        table.insert(addition_lines, context_line)
      end
      current_context = {}
      return true
    end
    return false
  end

  for _, line in ipairs(hunk) do
    if line:match("^@@") then
      goto continue
    end

    if line:match("^%-") then
      start_changes()
      table.insert(removal_lines, {
        content = vim.trim(line:sub(2)),
        full = line:sub(2)
      })
    elseif line:match("^%+") then
      start_changes()
      table.insert(addition_lines, {
        content = vim.trim(line:sub(2)),
        full = line:sub(2)
      })
    else
      table.insert(current_context, {
        content = vim.trim(line:sub(2)),
        full = line:sub(2)
      })
    end
    ::continue::
  end
  if #current_context > 0 then
    following_context = current_context
  end

  return removal_lines, addition_lines, preceding_context, following_context
end

-- Show inline diff for a single line
local function show_inline_diff(line_num, old_line, new_line)
  -- Find common prefix and suffix
  local prefix = common_prefix(old_line, new_line)
  local prefix_len = #prefix

  local suffix = common_suffix(old_line, new_line, prefix_len + 1, prefix_len + 1)
  local suffix_start_old = #old_line - #suffix + 1
  local suffix_start_new = #new_line - #suffix + 1

  -- Extract the changed portions
  local removed = old_line:sub(prefix_len + 1, suffix_start_old - 1)
  local added = new_line:sub(prefix_len + 1, suffix_start_new - 1)

  -- Create virtual lines for both the original and new line
  local virt_lines = {}

  -- Original line with strikethrough on changed part
  if prefix_len > 0 then
    table.insert(virt_lines, {
      { prefix,  "InlineSuggestionUnchanged" },
      { removed, "InlineSuggestionRemove" },
      { suffix,  "InlineSuggestionUnchanged" }
    })
  else
    table.insert(virt_lines, {
      { removed, "InlineSuggestionRemove" },
      { suffix,  "InlineSuggestionUnchanged" }
    })
  end

  -- New line with added part highlighted
  if prefix_len > 0 then
    table.insert(virt_lines, {
      { prefix, "InlineSuggestionUnchanged" },
      { added,  "InlineSuggestionAdd" },
      { suffix, "InlineSuggestionUnchanged" }
    })
  else
    table.insert(virt_lines, {
      { added,  "InlineSuggestionAdd" },
      { suffix, "InlineSuggestionUnchanged" }
    })
  end

  -- Create the extmark with virtual lines
  local extmark_id = vim.api.nvim_buf_set_extmark(0, ns_id, line_num - 1, 0, {
    virt_lines = virt_lines,
    virt_lines_above = true,
    hl_mode = "combine"
  })

  table.insert(current_extmarks, extmark_id)
end

-- Move context matching logic to a separate function
function M.find_context_match(buf, preceding_context, removal_lines, following_context)
  local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local matches = 0
  local start_line = nil
  -- function vim.list_extend(dst: <T:table>, src: table, start?: integer, finish?: integer)
  local context_lines = {}
  context_lines = vim.list_extend(context_lines, preceding_context)
  context_lines = vim.list_extend(context_lines, removal_lines)
  context_lines = vim.list_extend(context_lines, following_context)

  -- TODO this should probably just look at the removal lines at first, then use the context if there are multiple matches
  if #context_lines == 0 then
    return nil
  end

  for i, line in ipairs(buf_lines) do
    if vim.trim(line) == context_lines[1].content then
      start_line = i
      for j = 2, #context_lines do
        if not vim.trim(buf_lines[i + j - 1]) == context_lines[j].content then
          goto continue
        end
      end
      matches = matches + 1
    end
    ::continue::
  end

  if matches == 1 then
    return start_line + #preceding_context
  end
  return nil
end

-- Keep original function signatures but use the new components
function M.apply_changes()
  local result_buf = io_utils.get_result_buffer()
  print("Result buffer: ", result_buf)
  if not result_buf then
    vim.notify("No result buffer found", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(result_buf, 0, -1, false)
  local edits = M.parse_diff_hunks(lines)

  for _, edit in ipairs(edits) do
    local buf = vim.fn.bufnr(edit.path)
    if buf == -1 then
      -- try getting the current buffer
      buf = vim.api.nvim_get_current_buf()
      if buf == -1 then
        goto continue
      end
    end

    local removal_lines, addition_lines, preceding_context, following_context = M.process_hunk(edit.hunk)
    print("Removal lines: ", vim.inspect(removal_lines))

    if #preceding_context > 0 or #removal_lines > 0 or #following_context > 0 then
      local start_line = M.find_context_match(buf, preceding_context, removal_lines, following_context)
      print("Preceding context: ", vim.inspect(preceding_context))
      print("Following context: ", vim.inspect(following_context))
      print("Removal lines: ", vim.inspect(removal_lines))
      print("Start line: ", start_line)

      if start_line then
        -- insert #addition_lines lines starting from start_line
        local addition_lines_full = {}
        for i = 1, #addition_lines do
          table.insert(addition_lines_full, addition_lines[i].full)
        end
        vim.api.nvim_buf_set_lines(buf, start_line - 1, start_line + #removal_lines, false, addition_lines_full)
      end
    end
    ::continue::
  end

  clear_suggestions()
end

function M.apply_diff_changes()
  if #current_extmarks > 0 then
    M.apply_changes()
    return
  end

  local result_buf = io_utils.get_result_buffer()
  if not result_buf then
    vim.notify("No result buffer found", vim.log.levels.ERROR)
    return
  end

  clear_suggestions()
  local lines = vim.api.nvim_buf_get_lines(result_buf, 0, -1, false)
  local edits = M.parse_diff_hunks(lines)

  for _, edit in ipairs(edits) do
    local buf = vim.fn.bufnr(edit.path)
    if buf == -1 then goto continue end

    local removal_lines, addition_lines, preceding_context, following_context = M.process_hunk(edit.hunk)

    if #removal_lines > 0 or #preceding_context > 0 or #following_context > 0 then
      local start_line = M.find_context_match(buf, preceding_context, removal_lines, following_context)

      if start_line then
        for i = 1, #removal_lines do
          show_inline_diff(start_line + i - 1, removal_lines[i].full, addition_lines[i].full)
        end
      end
    end
    ::continue::
  end

  vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave" }, {
    callback = clear_suggestions,
    once = true
  })
end

function M.setup()
  setup_highlights()

  -- Create command to manually clear suggestions
  vim.api.nvim_create_user_command("ClearInlineSuggestions", clear_suggestions, {})
end

return M
