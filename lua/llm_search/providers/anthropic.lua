local curl = require("plenary.curl")
local utils = require("llm_search.providers.utils")

local M = {}

M.api_url = "https://api.anthropic.com/v1/messages"

-- Helper function to format tools for Anthropic API
local function format_tools(tools)
	local formatted_tools = {}
	for _, tool in ipairs(tools) do
		table.insert(formatted_tools, {
			name = tool.name,
			description = tool.description,
			parameters = tool.parameters,
		})
	end
	return formatted_tools
end

-- Helper function to handle tool calls
local function handle_tool_calls(tool_calls, tools, callback)
	for _, call in ipairs(tool_calls) do
		for _, tool in ipairs(tools) do
			if call.name == tool.name then
				-- Call the tool handler with the arguments and callback
				tool.handler(call.arguments, callback)
				break
			end
		end
	end
end

function M.request(model, messages, callback)
	local api_key = M.config.providers.anthropic.api_key
	-- Get the system message
	local system_message = vim.tbl_filter(function(message)
		return message.role == "system"
	end, messages)[1]
	-- Remove the system message from messages
	messages = vim.tbl_filter(function(message)
		return message.role ~= "system"
	end, messages)
	curl.post(M.api_url, {
		headers = {
			["Content-Type"] = "application/json",
			["x-api-key"] = api_key,
			["anthropic-version"] = "2023-06-01",
		},
		body = vim.fn.json_encode({
			model = model.name,
			messages = messages,
			max_tokens = 8192,
			system = system_message.content,
		}),
		callback = vim.schedule_wrap(function(response)
			if response.status ~= 200 then
				vim.notify(
					"API request failed with status " .. response.status .. "\n" .. response.body,
					vim.log.levels.ERROR
				)
				return
			end
			local result = vim.json.decode(response.body)
			callback(result.content[1].text)
		end),
	})
end

function M.stream(model, messages, callback, cleanup, tools)
	local api_key = M.config.providers.anthropic.api_key
	-- Get the system message
	local system_message = vim.tbl_filter(function(message)
		return message.role == "system"
	end, messages)[1]
	-- Remove the system message from messages
	messages = vim.tbl_filter(function(message)
		return message.role == "user"
	end, messages)
	local headers = {
		"Content-Type: application/json",
		"x-api-key: " .. api_key,
		"anthropic-version: 2023-06-01",
	}
	local body = {
		model = model.name,
		messages = messages,
		max_tokens = 8192,
		stream = true,
		system = system_message.content,
	}
	-- Add tools to the request if provided
	if tools then
		body.tools = format_tools(tools)
	end

	local stream = function(data)
		if data then
			local lines = vim.split(data, "\n")
			for _, line in ipairs(lines) do
				if line:match("^event:") then
					local event = line:gsub("^event:%s*", "")
					-- potential events: 
					-- ping, 
					-- message_start, 
					-- content_block_start,
					--
					if event == "end" then
						cleanup()
					end
				end
				if line:match("^data:") then
					local json_str = line:gsub("^data:%s*", "")
					if json_str ~= "[DONE]" then
						local result = vim.json.decode(json_str)
						if result.delta and result.delta.text then
							callback(result.delta.text)
						end
					end
				end
			end
		end
	end
	utils.run_curl_with_streaming({
		url = M.api_url,
		method = "POST",
		headers = headers,
		body = body,
		on_chunk = stream,
		cleanup = cleanup,
	})
end

function M.set_config(config)
	M.config = config
end

return M
