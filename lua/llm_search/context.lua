local M = {}

-- Store context data
local context_data = {}

function M.print_context()
  print(vim.inspect(context_data))
end

-- Add a file to context with optional description
function M.add_file(file_path, description)
  if not context_data[file_path] then
    context_data[file_path] = {
      type = "file",
      content = vim.fn.readfile(file_path),
      description = description or nil
    }
  end
end

-- Add current buffer/file to context
function M.add_current_buffer(description)
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == "" then
    vim.notify("Current buffer has no file path", vim.log.levels.WARN)
    return
  end

  M.add_file(buf_path, description)
end

-- Add a snippet to context with optional description
function M.add_snippet(snippet, start_line, end_line, file_path, description)
  local key = file_path .. ":" .. start_line .. "-" .. end_line
  context_data[key] = {
    type = "snippet",
    content = snippet,
    file = file_path,
    start_line = start_line,
    end_line = end_line,
    description = description or nil
  }
end

-- Add visual selection to context
function M.add_visual_selection(description)
  -- Get visual selection mode
  local mode = vim.fn.visualmode()

  -- Get visual selection positions
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Get buffer info
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == "" then
    vim.notify("Current buffer has no file path", vim.log.levels.WARN)
    return
  end

  -- Get selected lines
  local lines
  if mode == 'V' then -- Line-wise visual mode
    lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  else                -- Character-wise visual mode
    local start_col = start_pos[3]
    local end_col = end_pos[3]

    lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

    -- If selection is within a single line
    if start_line == end_line then
      lines[1] = string.sub(lines[1], start_col, end_col)
    else
      -- Trim first and last lines according to selection
      lines[1] = string.sub(lines[1], start_col)
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  end

  local snippet = table.concat(lines, "\n")
  M.add_snippet(snippet, start_line, end_line, buf_path, description)
end

-- Update description for an existing context element
function M.update_description(key, description)
  if context_data[key] then
    context_data[key].description = description
  else
    vim.notify("Context element not found: " .. key, vim.log.levels.WARN)
  end
end

-- Remove item from context
function M.remove(key)
  context_data[key] = nil
end

-- Clear all context
function M.clear()
  context_data = {}
end

function M.get_context_summary()
  local result = {}

  for key, data in pairs(context_data) do
    -- Add header with file path/key and description if available
    local header = "=== " .. key
    if data.description then
      header = header .. " (" .. data.description .. ")"
    end
    table.insert(result, header)
  end

  -- Join all parts with newlines
  local display_string = table.concat(result, "\n")

  -- Return the string
  return display_string
end

function M.get_context_string()
  local result = {}

  for key, data in pairs(context_data) do
    -- Add file path
    table.insert(result, "File: " .. (data.file or key))

    -- Add description if available
    if data.description then
      table.insert(result, "Description: " .. data.description)
    end

    -- Add line numbers for snippets
    if data.type == "snippet" then
      table.insert(result, string.format("Lines: %d-%d", data.start_line, data.end_line))
    end

    -- Add content
    if type(data.content) == "table" then
      table.insert(result, table.concat(data.content, "\n"))
    else
      table.insert(result, data.content)
    end

    -- Add separator between entries
    table.insert(result, "\n")
  end

  -- Join all parts with newlines and return
  return table.concat(result, "\n")
end

-- Get current context
function M.get_context()
  if next(context_data) == nil then
    return nil
  end
  return context_data
end

return M
