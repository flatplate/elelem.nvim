local M = {}

function M.get_last_change_diff()
  -- Store current state
  local current_buf = vim.api.nvim_get_current_buf()
  local current_lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)
  local file_path = vim.api.nvim_buf_get_name(current_buf)

  -- Store current position in undo tree
  local saved_changes = vim.fn.changenr()

  -- Go back 1 change
  vim.cmd('silent! undo')      -- Go to most recent change
  vim.cmd('silent! undo -1')   -- Go back 1 step

  -- Get old content
  local old_lines = vim.api.nvim_buf_get_lines(current_buf, 0, -1, false)

  -- Return to current state
  vim.cmd('silent! undo ' .. saved_changes)

  -- Generate git-style diff header
  local diff_content = {
    "diff --git a/" .. file_path .. " b/" .. file_path,
    "--- a/" .. file_path,
    "+++ b/" .. file_path,
    "@@ -1," .. #old_lines .. " +1," .. #current_lines .. " @@"
  }

  -- Compare and generate diff
  for i = 1, math.max(#current_lines, #old_lines) do
    local old_line = old_lines[i] or ''
    local new_line = current_lines[i] or ''

    if old_line == new_line then
      -- Identical lines
      table.insert(diff_content, " " .. new_line)
    else
      -- Changed lines
      if old_line ~= '' and new_line ~= '' and old_line ~= new_line then
        -- Line was modified
        table.insert(diff_content, "-" .. old_line)
        table.insert(diff_content, "+" .. new_line)
      elseif old_line ~= '' then
        -- Line was removed
        table.insert(diff_content, "-" .. old_line)
      elseif new_line ~= '' then
        -- Line was added
        table.insert(diff_content, "+" .. new_line)
      end
    end
  end

  if #diff_content == 4 then  -- Only header lines, no changes
    return "No changes in last undo step"
  end

  return table.concat(diff_content, '\n')
end

return M
