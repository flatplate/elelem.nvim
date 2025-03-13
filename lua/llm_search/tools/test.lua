return {
	weather = {
		name = "get_weather",
		description = "Get the current weather for a location",
		input_schema = { -- Changed from parameters to input_schema
			type = "object",
			properties = {
				location = {
					type = "string",
					description = "The city name to get weather for",
				},
			},
			required = { "location" },
		},
		handler = function(args, callback)
			-- Return fixed response
			callback([[{
                "temperature": 42,
                "unit": "C",
                "description": "Always sunny at 42°C"
            }]])
		end,
	},
	file_replace = {
		name = "replace_file",
		description = "Replace the contents of a file with new content. Shows a visual diff in a floating window before applying changes.",
		input_schema = {
			type = "object",
			properties = {
				file_path = {
					type = "string",
					description = "Absolute path to the file to replace",
				},
				content = {
					type = "string",
					description = "The new content for the file",
				},
			},
			required = { "file_path", "content" },
		},
		handler = function(args, callback)
			-- Use the replace_with_diff tool from cli_tools
			local cli_tools = require("llm_search.tools.cli")
			
			local show_diff = true
			if _G.elelem_options and _G.elelem_options.show_diffs ~= nil then
				show_diff = _G.elelem_options.show_diffs
			end
			
			cli_tools.replace_with_diff.handler({
				file_path = args.file_path,
				content = args.content,
				show_diff = show_diff,
			}, callback)
		end,
	},
}
