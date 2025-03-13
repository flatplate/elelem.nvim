local test_tools = require("llm_search.tools.test")
local lsp_tools = require("llm_search.tools.lsp")
local cli_tools = require("llm_search.tools.cli")

local M = {}

M.available_tools = {}

local add_tools_from_module = function(module)
	for k, v in pairs(module) do
		M.available_tools[k] = v
		print("Added tool: " .. k) -- Debug statement to see what tools are being added
	end
end

add_tools_from_module(test_tools)
add_tools_from_module(lsp_tools)
add_tools_from_module(cli_tools)

M.used_tools = {}

M.add_tool = function(tool_name)
	if M.available_tools[tool_name] then
		M.used_tools[tool_name] = M.available_tools[tool_name]
	end
end

M.remove_tool = function(tool_name)
	M.used_tools[tool_name] = nil
end

M.telescope_add_tool = function()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values

	local tool_names = vim.tbl_keys(M.available_tools)
	table.sort(tool_names)

	pickers
		.new({}, {
			prompt_title = "Add Tool",
			finder = finders.new_table({
				results = tool_names,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry()
					if selection then
						M.add_tool(selection.value)
					end
					require("telescope.actions").close(prompt_bufnr)
				end)
				return true
			end,
		})
		:find()
end

M.telescope_remove_tool = function()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values

	local tool_names = vim.tbl_keys(M.used_tools)
	table.sort(tool_names)

	pickers
		.new({}, {
			prompt_title = "Remove Tool",
			finder = finders.new_table({
				results = tool_names,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = require("telescope.actions.state").get_selected_entry()
					if selection then
						M.remove_tool(selection.value)
					end
					require("telescope.actions").close(prompt_bufnr)
				end)
				return true
			end,
		})
		:find()
end

M.get_used_tools_list = function()
	local tools = {}
	for _, tool in pairs(M.used_tools) do
		table.insert(tools, tool)
	end
	-- Sort by tool name instead of trying to compare tool tables directly
	table.sort(tools, function(a, b)
		return (a.name or "") < (b.name or "")
	end)
	return tools
end

M.get_available_tools_list = function()
	local tools = {}
	for name, _ in pairs(M.available_tools) do
		table.insert(tools, name)
	end
	table.sort(tools)
	return tools
end

-- Debug function to print all available tools
M.debug_print_tools = function()
	print("Available tools directly from modules:")
	print("From test_tools:")
	for k, _ in pairs(test_tools) do
		print("  - " .. k)
	end
	
	print("From lsp_tools:")
	for k, _ in pairs(lsp_tools) do
		print("  - " .. k)
	end
	
	print("From cli_tools:")
	for k, _ in pairs(cli_tools) do
		print("  - " .. k)
	end
	
	print("\nRegistered available_tools:")
	for name, _ in pairs(M.available_tools) do
		print("  - " .. name)
	end
	
	print("\nActive used_tools:")
	for name, _ in pairs(M.used_tools) do
		print("  - " .. name)
	end
end

return M
