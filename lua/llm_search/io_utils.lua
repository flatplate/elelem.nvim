-- Function to create a popup input
local function popup_input(callback)
  local Input = require("nui.input")
  local event = require("nui.utils.autocmd").event

  local input = Input({
    position = "50%",
    size = {
      width = 60,
    },
    border = {
      style = "rounded",
      text = {
        top = "Enter your query",
        top_align = "center",
      },
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  }, {
    prompt = "> ",
    default_value = "",
    on_close = function()
      print("Input cancelled")
    end,
    on_submit = function(value)
      callback(value)
    end,
  })

  input:mount()

  input:on(event.BufLeave, function()
    input:unmount()
  end)
end

-- Function to create a new split and print content
local function print_to_split(content)
  vim.cmd("vnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
end

-- Global variable to store the buffer number
local result_bufnr = nil

-- Function to get or create the result buffer
local function get_result_buffer()
  if result_bufnr and vim.api.nvim_buf_is_valid(result_bufnr) then
    return result_bufnr
  end

  -- Check if a buffer with the name already exists
  local existing_bufnr = vim.fn.bufnr("LLM Search Results")
  if existing_bufnr ~= -1 and vim.api.nvim_buf_is_valid(existing_bufnr) then
    result_bufnr = existing_bufnr
    return result_bufnr
  end

  -- Create a new buffer
  result_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(result_bufnr, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(result_bufnr, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(result_bufnr, 'swapfile', false)
  -- set filetype to markdown
  vim.api.nvim_buf_set_option(result_bufnr, 'filetype', 'markdown')

  -- Only set the name if it's a new buffer
  vim.api.nvim_buf_set_name(result_bufnr, "LLM Search Results")

  return result_bufnr
end

-- Function to display content in the result buffer
local function display_in_result_buffer(content)
  local bufnr = get_result_buffer()

  -- Find or create a window for the buffer
  local winid = vim.fn.bufwinid(bufnr)
  if winid == -1 then
    vim.cmd('vsplit')
    winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(winid, bufnr)
  else
    vim.api.nvim_set_current_win(winid)
  end

  -- Clear the buffer and set its content
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(content, "\n"))
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

  -- Set 'wrap' option for the window
  vim.api.nvim_win_set_option(winid, 'wrap', true)

  -- Move cursor to the top of the buffer
  vim.api.nvim_win_set_cursor(winid, { 1, 0 })
end

local function append_to_result_buffer(content)
  vim.schedule(function()
    local bufnr = get_result_buffer()

    local winid = vim.fn.bufwinid(bufnr)
    if winid == -1 then
      vim.cmd('vsplit')
      winid = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(winid, bufnr)
    else
      vim.api.nvim_set_current_win(winid)
    end

    vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
    local last_line = vim.api.nvim_buf_line_count(bufnr)
    local last_line_content = vim.api.nvim_buf_get_lines(bufnr, last_line - 1, last_line, false)[1] or ""

    if last_line_content ~= "" then
      vim.api.nvim_buf_set_lines(bufnr, last_line - 1, last_line, false, { last_line_content .. content })
    else
      vim.api.nvim_buf_set_lines(bufnr, last_line - 1, last_line, false, { content })
    end

    vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)

    vim.api.nvim_win_set_option(winid, 'wrap', true)

    local new_last_line = vim.api.nvim_buf_line_count(bufnr)
    vim.api.nvim_win_set_cursor(winid, { new_last_line, #content })
  end)
end

local function clear_result_buffer()
  local bufnr = get_result_buffer()
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
end

local M = {
  popup_input = popup_input,
  print_to_split = print_to_split,
  get_result_buffer = get_result_buffer,
  display_in_result_buffer = display_in_result_buffer,
  append_to_result_buffer = append_to_result_buffer,
  clear_result_buffer = clear_result_buffer,
}

return M
