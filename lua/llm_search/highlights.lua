local io_utils = require("llm_search.io_utils")

local M = {}

-- Create namespace for extmarks
local ns_id = vim.api.nvim_create_namespace("inline_suggestions")
local current_extmarks = {}

-- Setup highlight groups
local function setup_highlights()
  vim.api.nvim_set_hl(0, "InlineSuggestionRemove", { fg = "#F47067", strikethrough = true })
  vim.api.nvim_set_hl(0, "InlineSuggestionAdd", { fg = "#4EC994", italic = true })
  vim.api.nvim_set_hl(0, "InlineSuggestionUnchanged", { fg = "#808080" })
end

local function apply_line_change(line_num, old_line, new_line)
  -- Replace the line in the buffer
  vim.api.nvim_buf_set_lines(0, line_num - 1, line_num, false, { new_line })
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

function M.apply_changes()
  local result_buf = io_utils.get_result_buffer()
  if not result_buf then
    vim.notify("No result buffer found", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(result_buf, 0, -1, false)
  local in_code_block = false
  local current_hunk = {}
  local hunks = {}

  -- Parse hunks from buffer
  for _, line in ipairs(lines) do
    if line == "```" then
      if in_code_block then
        if #current_hunk > 0 and current_hunk[1]:match("^@@") then
          table.insert(hunks, table.concat(current_hunk, "\n"))
        end
        current_hunk = {}
      end
      in_code_block = not in_code_block
    elseif in_code_block then
      table.insert(current_hunk, line)
    end
  end

  -- Process each hunk
  for _, hunk in ipairs(hunks) do
    local line_num = tonumber(string.match(hunk, '@@ (%d+)'))
    if not line_num then goto continue end

    local removal_lines = {}
    local addition_lines = {}

    -- Extract content parts of removal/addition lines
    for line in vim.gsplit(hunk, "\n") do
      if line:match("^%- ") then
        table.insert(removal_lines, {
          content = vim.trim(line:sub(3)),
          full = line:sub(3)
        })
      elseif line:match("^%+ ") then
        table.insert(addition_lines, {
          content = vim.trim(line:sub(3)),
          full = line:sub(3)
        })
      end
    end

    if #removal_lines > 0 then
      local current_lines = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num - 1 + #removal_lines, false)
      local matches = true

      -- Check if the current lines match the removal lines
      for i = 1, #removal_lines do
        local current_content = vim.trim(current_lines[i] or "")
        if current_content ~= removal_lines[i].content then
          matches = false
          break
        end
      end

      if matches then
        -- Apply changes for each line
        for i = 1, math.max(#removal_lines, #addition_lines) do
          local old_line = removal_lines[i] and removal_lines[i].full or ""
          local new_line = addition_lines[i] and addition_lines[i].full or ""
          if old_line ~= new_line then
            apply_line_change(line_num + i - 1, old_line, new_line)
          end
        end
      end
    end
    ::continue::
  end

  -- Clear suggestions after applying changes
  clear_suggestions()
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

function M.apply_diff_changes()
  -- If we are already showing suggestions, apply changes and return
  if #current_extmarks > 0 then
    M.apply_changes()
    return
  end
  local result_buf = io_utils.get_result_buffer()
  if not result_buf then
    vim.notify("No result buffer found", vim.log.levels.ERROR)
    return
  end

  -- Clear any existing suggestions
  clear_suggestions()

  local lines = vim.api.nvim_buf_get_lines(result_buf, 0, -1, false)
  local in_code_block = false
  local current_hunk = {}
  local hunks = {}

  -- Parse hunks from buffer
  for _, line in ipairs(lines) do
    if line == "```" then
      if in_code_block then
        if #current_hunk > 0 and current_hunk[1]:match("^@@") then
          table.insert(hunks, table.concat(current_hunk, "\n"))
        end
        current_hunk = {}
      end
      in_code_block = not in_code_block
    elseif in_code_block then
      table.insert(current_hunk, line)
    end
  end

  -- Process each hunk
  for _, hunk in ipairs(hunks) do
    local line_num = tonumber(string.match(hunk, '@@ (%d+)'))
    if not line_num then goto continue end

    local removal_lines = {}
    local addition_lines = {}

    -- Extract content parts of removal/addition lines
    for line in vim.gsplit(hunk, "\n") do
      if line:match("^%- ") then
        table.insert(removal_lines, {
          content = vim.trim(line:sub(3)),
          full = line:sub(3)
        })
      elseif line:match("^%+ ") then
        table.insert(addition_lines, {
          content = vim.trim(line:sub(3)),
          full = line:sub(3)
        })
      end
    end

    if #removal_lines > 0 then
      local current_lines = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num - 1 + #removal_lines, false)
      local matches = true

      -- Check if the current lines match the removal lines
      for i = 1, #removal_lines do
        local current_content = vim.trim(current_lines[i] or "")
        if current_content ~= removal_lines[i].content then
          matches = false
          break
        end
      end

      if matches then
        -- For each pair of lines, show inline diff
        for i = 1, math.max(#removal_lines, #addition_lines) do
          local old_line = removal_lines[i] and removal_lines[i].full or ""
          local new_line = addition_lines[i] and addition_lines[i].full or ""
          if old_line ~= new_line then
            show_inline_diff(line_num + i - 1, old_line, new_line)
          end
        end
      end
    end
    ::continue::
  end

  -- Setup autocommands to clear suggestions
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
