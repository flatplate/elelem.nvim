# elelem.nvim

Yet another LLM plugin for Neovim

## Description

elelem.nvim is a powerful Neovim plugin that integrates Large Language Models (LLMs) into your coding workflow. It allows you to search and interact with your code using natural language queries, enhancing your productivity and code understanding.

## Features

- Search quickfix list with LLM assistance
- Query current file content
- Query visual selections
- Append LLM-generated content to your code
- Support for multiple providers and models
- Customizable prompts
- Logging for debugging

## Installation

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  'flatplate/elelem.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    -- Add other dependencies if needed
  }
}
```

Using lazy
```lua
{
  'flatplate/elelem.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    -- Add other dependencies if needed
  },
  config = function()
    require('elelem').setup({
      -- Add your configuration options here
    })
  end,
}
```


## Configuration

```lua
elelem.setup({
  providers = {
    fireworks = {
      api_key = env_vars.FIREWORKS_API_KEY
    },
    anthropic = {
      api_key = env_vars.ANTHROPIC_API_KEY
    },
    openai = {
      api_key = env_vars.OPENAI_API_KEY
    }
  }
})
```

You probably don't want to just put your API keys in your configuration file.
What I do is read a .env file in my config and use the api keys like that. If
there is a better way let me know.

```lua

## Usage

elelem.nvim provides several functions to interact with your code:

1. Search quickfix list:
   ```lua
   :lua require('elelem').search_quickfix()
   ```

2. Search current file:
   ```lua
   :lua require('elelem').search_current_file()
   ```

3. Search visual selection:
   ```lua
   :lua require('elelem').search_visual_selection()
   ```

4. Append LLM output:
   ```lua
   :lua require('elelem').append_llm_output()
   ```

5. Append LLM output to visual selection:
   ```lua
   :lua require('elelem').append_llm_output_visual()
   ```

My keymaps look like this

```lua
local gpt4omini = require("elelem").models.gpt4omini
local claude_3_5_sonnet = require("elelem").models.claude_3_5_sonnet
-- Same as the comments below
vim.keymap.set('n', '<leader>wq', function()
  elelem.search_quickfix("Answer only what is asked short and concisely. Give references to the file names when you say something. ", gpt4omini)
end, { desc = 'Search [W]ith [Q]uickfix' })
vim.keymap.set('n', '<leader>ww', function()
  elelem.search_current_file("Answer only what is asked short and concisely. ", gpt4omini)
end, { desc = 'Query Current File' })
vim.keymap.set('n', '<leader>we', function()
  elelem.search_current_file("", claude_3_5_sonnet)
end, { desc = 'Query Current File with sonnet' })
vim.keymap.set('n', '<leader>wa', function()
  elelem.append_llm_output("You write code that will be put in the lines marked with [Append here] and write code for what the user asks. Do not provide any explanations, just write code. Only return code. Only code no explanation", claude_3_5_sonnet)
end, { desc = 'Append to cursor location with sonnet' })

vim.keymap.set('v', '<leader>we', function()
  elelem.search_visual_selection("", claude_3_5_sonnet)
end, { desc = 'Query selection with sonnet' })
vim.keymap.set('v', '<leader>wa', function()
  elelem.append_llm_output_visual("You write code that will be put in the lines marked with [Append here] and write code for what the user asks. Do not provide any explanations, just write code. Only return code. Only code no explanation", claude_3_5_sonnet)
end, { desc = 'Append selection with sonnet' })
```

## Custom Prompts and Models

You can specify custom prompts and models for each function:

```lua
:lua require('elelem').search_quickfix("Your custom prompt", require('elelem').models.gpt4)
```

## Logging

To view the log file:

```lua
:lua require('elelem').open_log_file()
```

## License

The MIT License (MIT)

Copyright (c) 2015 Chris Kibble

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

