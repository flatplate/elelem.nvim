local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local context = require("llm_search.context")

local M = {}

local function create_display_string(entry)
  local type_icon = entry.type == "file" and "📄 " or "✂️ "
  local display = type_icon .. (entry.key or "")

  if entry.description then
    display = display .. " (" .. entry.description .. ")"
  end

  return display
end

-- Create a custom previewer
local context_previewer = previewers.new_buffer_previewer({
  title = "Elelem Context Preview",
  get_buffer_by_name = function(_, entry)
    return entry.key
  end,
  define_preview = function(self, entry)
    local content = entry.item.content
    if type(content) == "table" then
      content = table.concat(content, "\n")
    end
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(content, "\n"))

    -- Set filetype if it's from a file
    if entry.item.file then
      local ft = vim.filetype.match({ filename = entry.item.file })
      if ft then
        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", ft)
      end
    end
  end,
})

function M.context_picker()
  local context_data = context.get_context()
  if not context_data then
    vim.notify("No context items found", vim.log.levels.WARN)
    return
  end

  local items = {}
  for key, item in pairs(context_data) do
    table.insert(items, {
      key = key,
      type = item.type,
      description = item.description,
      item = item
    })
  end

  pickers.new({}, {
    prompt_title = "Context Items",
    finder = finders.new_table({
      results = items,
      entry_maker = function(entry)
        return {
          value = entry,
          display = create_display_string(entry),
          ordinal = entry.key,
          key = entry.key,
          type = entry.type,
          item = entry.item
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = context_previewer,
    attach_mappings = function(prompt_bufnr, map)
      -- Delete context item
      map("i", "<c-d>", function()
        local selection = action_state.get_selected_entry()
        context.remove(selection.key)
        actions.close(prompt_bufnr)
        M.context_picker() -- Reopen picker to reflect changes
      end)

      -- Edit description
      map("i", "<c-e>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        -- Prompt for new description
        vim.ui.input({
          prompt = "Enter new description: ",
          default = selection.item.description or "",
        }, function(input)
          if input then
            context.update_description(selection.key, input)
            M.context_picker() -- Reopen picker to reflect changes
          end
        end)
      end)

      -- Keep default mappings
      return true
    end,
  }):find()
end

return M
