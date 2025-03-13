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
- Visual diffs in floating windows when modifying files
- Customizable prompts
- Logging for debugging
- LSP integration for diagnostics, definitions, and references
- Tool use support for advanced AI capabilities:
  - CLI command execution with security checks
  - File manipulation with diff previews and confirmations
  - Smart code replacement with whitespace normalization
- Support for the latest LLM models:
  - Claude 3.5 Sonnet and Haiku with tool use
  - Llama 3.1 models via Fireworks and Groq
  - DeepSeek-r1 and DeepSeek v3
  - Gemma 2 models

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
    },
    groq = {
      api_key = env_vars.GROQ_API_KEY
    }
  },
  
  -- UI options
  show_diffs = true, -- Show diffs in a floating window when files are modified (default: true)
  
  -- LSP integration
  lsp = {
    enable_diagnostics = true, -- Enable gathering LSP diagnostics in context (default: true)
    enable_definitions = true, -- Enable gathering symbol definitions in context (default: true)
    enable_references = true,  -- Enable gathering symbol references in context (default: true)
  },
  
  -- Tool use options
  tools = {
    enable = true,             -- Enable tool use features when supported by models (default: true)
    require_confirmation = true, -- Require user confirmation before applying file changes (default: true)
    default_tools = {          -- List of tools to enable automatically at startup
      "replace",               -- For replacing code with diff preview
      "replace_with_diff",     -- For replacing entire files
      "cli",                   -- For executing terminal commands
      "lsp_fix"                -- For LSP-based fixes
    },
    verbose = false            -- Set to true to show tool initialization messages
  }
})
```

You probably don't want to just put your API keys in your configuration file.
What I do is read a .env file in my config and use the api keys like that. If
there is a better way let me know.

## Usage

elelem.nvim provides several functions to interact with your code:

### Basic Functions

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

### LSP Integration

1. Get LSP diagnostics for current file:
   ```lua
   :lua require('elelem').get_diagnostics()
   ```

2. Find and fix issues with LSP diagnostics:
   ```lua
   :lua require('elelem').fix_diagnostics()
   ```

3. Find symbol definitions with LSP:
   ```lua
   :lua require('elelem').get_definition()
   ```

4. Find symbol references with LSP:
   ```lua
   :lua require('elelem').get_references()
   ```

### Tool Use Functions

Tool use is automatically supported for compatible models like Claude 3.5 Sonnet/Haiku. The tools allow the AI to:

- Execute CLI commands with user confirmation
- Modify files with interactive diff previews  
- Replace code with whitespace-aware matching
- See changes before applying them

When using a tool-enabled model, you'll get a UI prompt to confirm any changes before they're applied.

### Example Keymapping Configuration

Here's an example of comprehensive keymappings for both basic and advanced features:

```lua
local elelem = require("elelem")

-- Import models
local gpt4omini = elelem.models.gpt4omini
local claude_3_5_sonnet = elelem.models.claude_3_5_sonnet
local llama_3_1_8B = elelem.models.llama_3_1_8B
local deepseek_r1 = elelem.models.deepseek_r1

-- Basic search functions
vim.keymap.set('n', '<leader>wq', function()
  elelem.search_quickfix("Answer only what is asked short and concisely. Give references to the file names when you say something. ", gpt4omini)
end, { desc = 'Search with Quickfix (GPT-4o-mini)' })

vim.keymap.set('n', '<leader>ww', function()
  elelem.search_current_file("Answer only what is asked short and concisely. ", gpt4omini)
end, { desc = 'Query Current File (GPT-4o-mini)' })

vim.keymap.set('n', '<leader>we', function()
  elelem.search_current_file("", claude_3_5_sonnet)
end, { desc = 'Query Current File with Claude 3.5 Sonnet' })

-- Code generation with tool use enabled model
vim.keymap.set('n', '<leader>wa', function()
  elelem.append_llm_output("You write code that will be put in the lines marked with [Append here]. Do not provide any explanations, just write code.", claude_3_5_sonnet)
end, { desc = 'Append Code with Claude 3.5 Sonnet' })

-- Visual selection operations
vim.keymap.set('v', '<leader>we', function()
  elelem.search_visual_selection("", claude_3_5_sonnet)
end, { desc = 'Query Selection with Claude 3.5 Sonnet' })

vim.keymap.set('v', '<leader>wa', function()
  elelem.append_llm_output_visual("You write code that will be put in the lines marked with [Append here]. Do not provide explanations.", claude_3_5_sonnet)
end, { desc = 'Append to Selection with Claude 3.5 Sonnet' })

-- LSP features
vim.keymap.set('n', '<leader>wd', function()
  elelem.get_diagnostics(claude_3_5_sonnet)
end, { desc = 'Get LSP Diagnostics with Claude 3.5 Sonnet' })

vim.keymap.set('n', '<leader>wf', function()
  elelem.fix_diagnostics(claude_3_5_sonnet)
end, { desc = 'Fix LSP Issues with Claude 3.5 Sonnet' })

vim.keymap.set('n', '<leader>ws', function()
  elelem.get_definition(claude_3_5_sonnet)
end, { desc = 'Get Symbol Definition with Claude 3.5 Sonnet' })

vim.keymap.set('n', '<leader>wr', function()
  elelem.get_references(claude_3_5_sonnet)
end, { desc = 'Get Symbol References with Claude 3.5 Sonnet' })

-- Quick model switching examples
vim.keymap.set('n', '<leader>wl', function()
  elelem.search_current_file("", llama_3_1_8B)
end, { desc = 'Query with Llama 3.1 8B' })

vim.keymap.set('n', '<leader>wk', function()
  elelem.search_current_file("", deepseek_r1)
end, { desc = 'Query with DeepSeek-r1' })
```

## Custom Prompts and Models

You can specify custom prompts and models for each function:

```lua
:lua require('elelem').search_quickfix("Your custom prompt", require('elelem').models.claude_3_5_sonnet)
```

### Available Models

elelem.nvim provides access to many recent models across different providers:

#### Anthropic Models
- `models.claude_3_opus`: Claude 3 Opus
- `models.claude_3_5_sonnet`: Claude 3.5 Sonnet (with tool use)
- `models.claude_3_haiku`: Claude 3 Haiku
- `models.claude_3_5_haiku`: Claude 3.5 Haiku (with tool use)
- `models.claude_2`: Claude 2.1

#### OpenAI Models
- `models.gpt4omini`: GPT-4o-mini
- `models.gpt4o`: GPT-4o
- `models.o3_mini`: o3-mini

#### Fireworks Models
- `models.deepseek`: DeepSeek Coder v2 Lite
- `models.deepseek_base`: DeepSeek Coder v2
- `models.deepseek_3`: DeepSeek v3
- `models.deepseek_r1`: DeepSeek r1
- `models.gemma`: Gemma 2 9B
- `models.llama_3_1_405B_fireworks`: Llama 3.1 405B
- `models.llama_3_1_70B_fireworks`: Llama 3.1 70B
- `models.llama_3_1_8B_fireworks`: Llama 3.1 8B
- `models.qwen`: Qwen 2.5 72B

#### Groq Models
- `models.llama_3_1_405B`: Llama 3.1 405B
- `models.llama_3_1_70B`: Llama 3.3 70B (with tool use)
- `models.llama_3_1_8B`: Llama 3.1 8B
- `models.gemma_2_9B`: Gemma 2 9B
- `models.deepseek_r1_llama_70b`: DeepSeek r1 Distill Llama 70B (with tool use)

Models with `supports_tool_use = true` can interact with your environment through the plugin's tool system, allowing for more powerful code editing capabilities.

### Available Tools

The following tools can be enabled for LLM use:

- `replace`: Smart code replacement with diff preview and whitespace normalization
- `replace_with_diff`: Replace entire files with diff preview
- `replace_by_lines`: Replace specific line ranges in files
- `cli`: Execute shell commands with security checks
- `lsp_fix`: Fix diagnostics using LSP

#### Tool Management

You can manage tools programmatically:

```lua
-- Add tools individually
require('elelem').add_tool("replace")
require('elelem').add_tool("cli")

-- Remove tools
require('elelem').remove_tool("cli")

-- Get list of currently enabled tools
local active_tools = require('elelem').get_used_tools()

-- Show available and enabled tools in console
require('elelem').debug_print_tools()

-- Open interactive tool selector
require('elelem').telescope_add_tool()
require('elelem').telescope_remove_tool()
```

Or configure them to load automatically at startup (recommended):

```lua
elelem.setup({
  -- Other configuration...
  tools = {
    default_tools = { "replace", "replace_with_diff", "cli", "lsp_fix" },
    verbose = true  -- Show initialization messages
  }
})
```

## Logging

To view the log file:

```lua
:lua require('elelem').open_log_file()
```

## License

The MIT License (MIT)

Copyright (c) 2024 Ural Bayhan

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

