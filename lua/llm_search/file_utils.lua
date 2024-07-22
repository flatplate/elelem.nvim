local M = {}


--- Get the lines from a file
--- @param filename string: The name of the file
--- @param start number: The starting line number
--- @param end_line number: The ending line number
--- @return table: A table of lines from the file
local function get_file_lines(filename, start, end_line)
  local lines = {}
  local file = io.open(filename, "r")
  if file then
    local line_num = 1
    for line in file:lines() do
      if line_num >= start and line_num <= end_line then
        table.insert(lines, line)
      end
      if line_num > end_line then
        break
      end
      line_num = line_num + 1
    end
    file:close()
  end
  return lines
end

--- Function to get context lines around specific lines
--- @param bufnr number: The buffer number
--- @param line_numbers table: A table of line numbers
--- @param texts table: A table of text corresponding to the line numbers
--- @param context_lines number: The number of context lines to include
--- @return string: The context lines
local function get_context(bufnr, line_numbers, texts, context_lines)
  if not bufnr or #line_numbers == 0 then
    return ""
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local lines = {}

  table.insert(lines, "File: " .. filename)

  -- Create a set of quickfix line numbers for quick lookup
  local qf_lines = {}
  for i, lnum in ipairs(line_numbers) do
    qf_lines[lnum] = texts[i]
  end

  -- Find the min and max line numbers
  local min_line = math.min(unpack(line_numbers))
  local max_line = math.max(unpack(line_numbers))

  -- Extend the range by CONTEXT_LINES
  local start = math.max(1, min_line - context_lines)
  local end_line = max_line + context_lines

  local buf_lines
  if vim.api.nvim_buf_is_loaded(bufnr) then
    -- If the buffer is loaded, use the API to get lines
    end_line = math.min(vim.api.nvim_buf_line_count(bufnr), end_line)
    buf_lines = vim.api.nvim_buf_get_lines(bufnr, start - 1, end_line, false)
  else
    -- If the buffer is not loaded, read from the file
    buf_lines = get_file_lines(filename, start, end_line)
  end

  local function should_include_line(lnum)
    -- Check if line number is in the context of any of the quickfix lines
    for _, qf_lnum in ipairs(line_numbers) do
      if lnum >= qf_lnum - context_lines and lnum <= qf_lnum + context_lines then
        return true
      end
    end
    return false
  end
  -- Add lines to the context, highlighting quickfix lines
  for i, line in ipairs(buf_lines) do
    local current_line = start + i - 1
    if qf_lines[current_line] then
      table.insert(lines, string.format("(match)%d: %s", current_line, qf_lines[current_line]))
    elseif should_include_line(current_line) then
      table.insert(lines, string.format("%d: %s", current_line, line))
    end
  end

  return table.concat(lines, "\n")
end

--- Function to consolidate nearby lines from the same file
--- @param qf_list table: A table of quickfix items
--- @param context_lines number: The number of context lines to include
--- @return string: The consolidated context
local function consolidate_context(qf_list, context_lines)
  local consolidated = {}
  local current_bufnr = nil
  local current_lines = {}
  local current_texts = {}

  for _, item in ipairs(qf_list) do
    if item.bufnr and item.lnum then
      if item.bufnr ~= current_bufnr then
        if #current_lines > 0 and current_bufnr ~= nil then
          table.insert(consolidated, get_context(current_bufnr, current_lines, current_texts, context_lines))
        end
        current_bufnr = item.bufnr
        current_lines = { item.lnum }
        current_texts = { item.text }
      else
        table.insert(current_lines, item.lnum)
        table.insert(current_texts, item.text)
      end
    else
      if #current_lines > 0 and current_bufnr ~= nil then
        table.insert(consolidated, get_context(current_bufnr, current_lines, current_texts, context_lines))
        current_lines = {}
        current_texts = {}
        current_bufnr = nil
      end
      table.insert(consolidated, string.format("Item: %s", item.text or vim.inspect(item)))
    end
  end

  if #current_lines > 0 and current_bufnr ~= nil then
    table.insert(consolidated, get_context(current_bufnr, current_lines, current_texts, context_lines))
  end

  return table.concat(consolidated, "\n\n")
end

-- Function to get the content of the current file
local function get_current_file_content()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local content = "File: " .. filename .. "\n\n"
  content = content .. table.concat(lines, "\n")

  return content
end

local function get_current_file_content_with_append_marker(bufnr, row, col)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Insert the [Append here] marker at the cursor position
  local cursor_line = lines[row]
  local before_cursor = cursor_line:sub(1, col)
  local after_cursor = cursor_line:sub(col + 1)
  lines[row] = before_cursor .. "[Append here]" .. after_cursor

  local context = "File: " .. filename .. "\n\n"
  context = context .. table.concat(lines, "\n")

  return context
end

M.consolidate_context = consolidate_context
M.get_context = get_context
M.get_file_lines = get_file_lines
M.get_current_file_content = get_current_file_content
M.get_current_file_content_with_append_marker = get_current_file_content_with_append_marker

return M
