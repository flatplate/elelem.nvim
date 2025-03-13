local curl = require("plenary.curl")
local utils = require("llm_search.providers.utils")

local M = {}

M.api_url = "https://api.groq.com/openai/v1/chat/completions"

-- Convert Anthropic-style tools to OpenAI/Groq format
local function format_tools(tools)
	local formatted_tools = {}
	for _, tool in ipairs(tools) do
		table.insert(formatted_tools, {
			type = "function",
			["function"] = {
				name = tool.name,
				description = tool.description,
				parameters = tool.input_schema,
			},
		})
	end
	return formatted_tools
end

local function process_groq_tool_call(state, tool_call)
	if tool_call.type ~= "function" then
		return
	end

	-- Convert zero-based index to Lua's 1-based index
	local idx = tool_call.index + 1

	-- Initialize tool call entry if not exists
	if not state.tool_calls[idx] then
		local arguments = tool_call["function"].arguments
		-- Try to parse arguments as JSON if it's a string
		local parsed_arguments
		if type(arguments) == "string" then
			local success, result = pcall(vim.json.decode, arguments)
			if success then
				parsed_arguments = vim.deepcopy(result)
			else
				-- If JSON parsing fails, use original string
				parsed_arguments = arguments
				print("Failed to parse tool arguments as JSON: " .. result, vim.log.levels.WARN)
			end
		else
			parsed_arguments = arguments
		end

		state.tool_calls[idx] = {
			id = tool_call.id,
			name = tool_call["function"].name,
			arguments = parsed_arguments,
		}
	end
end

local function handle_tool_calls(tool_calls, tools, output_callback, final_callback)
	local pending = #tool_calls
	local responses = {}

	for _, call in ipairs(tool_calls) do
		for _, tool in ipairs(tools) do
			if call.name == tool.name then
				print("calling handler")
				
				-- First, add tool call message to the chat
				local call_args
				if type(call.arguments) == "table" then
					call_args = vim.inspect(call.arguments)
				else
					call_args = tostring(call.arguments)
				end
				output_callback("\n\n[Tool Call]: " .. call.name .. "\n```json\n" .. call_args .. "\n```")
				
				tool.handler(call.arguments, function(response)
					print("Handler callback")
					responses[call.id] = response
					
					-- Add tool response to the chat
					output_callback("\n\n[Tool Response]: " .. call.name .. "\n" .. response)
					
					pending = pending - 1
					if pending == 0 then
						-- Then proceed with final callback
						final_callback(responses)
					end
				end)
				break
			end
		end
	end
end

function M.request(model, messages, callback)
	local api_key = M.config.providers.groq.api_key
	curl.post(M.api_url, {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. api_key,
		},
		body = vim.fn.json_encode({
			model = model.name,
			messages = messages,
			max_tokens = 32000,
		}),
		callback = vim.schedule_wrap(function(response)
			if response.status ~= 200 then
				print(
					"API request failed with status " .. response.status .. "\n" .. response.body,
					vim.log.levels.ERROR
				)
				return
			end
			local result = vim.json.decode(response.body)
			callback(result.choices[1].message.content)
		end),
	})
end

function M.stream(model, messages, callback, cleanup, tools, prev_system_message)
	local api_key = M.config.providers.groq.api_key
	local headers = {
		"Content-Type: application/json",
		"Authorization: Bearer " .. api_key,
	}

	local body = {
		model = model.name,
		messages = messages,
		max_tokens = 32000,
		stream = true,
	}
	local messages_copy = vim.deepcopy(messages)

	-- Add tools if provided
	if tools then
		body.tools = format_tools(tools)
	end

	-- State tracking for tool calls (same as Anthropic)
	local state = {
		tool_calls = {},
		current_tool_call = nil,
		tool_call_messages = {},
	}

	cleanup = cleanup or function() end

	local stream = function(data)
		if data then
			local lines = vim.split(data, "\n")
			for _, line in ipairs(lines) do
				if line:match("^data:") then
					local json_str = line:gsub("^data:%s*", "")
					if json_str == "[DONE]" then
						return
					end

					local result = vim.json.decode(json_str)
					if not result then
						return
					end

					if result.choices and result.choices[1].delta then
						local delta = result.choices[1].delta

						-- Handle tool calls
						if delta.tool_calls then
							table.insert(messages_copy, {
								role = "assistant",
								tool_calls = delta.tool_calls,
							})
							for _, tool_call in ipairs(delta.tool_calls) do
								process_groq_tool_call(state, tool_call)
							end
						end

						table.insert(state.tool_call_messages, result)

						-- Handle text content
						if delta.content then
							-- Add the content to the latest message in messages copy if the last role is assistant
							-- Otherwise, add a new message with the content
							if #messages_copy > 0 and messages_copy[#messages_copy].role == "assistant" then
								messages_copy[#messages_copy].content = messages_copy[#messages_copy].content
									.. delta.content
							else
								table.insert(messages_copy, {
									role = "assistant",
									content = delta.content,
								})
							end
							callback(delta.content)
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
		on_chunk = function(data)
			-- Previous streaming content handling ...

			-- Handle final tool calls
			if data:match('"finish_reason":"tool_calls"') then
				print("Processing completed tool calls", vim.log.levels.INFO)

				if #state.tool_calls > 0 then
					handle_tool_calls(state.tool_calls, tools, callback, function(responses)
						-- Build new messages array

						-- Add assistant's tool call message
						-- Add tool responses
						for call_id, resp in pairs(responses) do
							print("Adding tool response to messages_copy", vim.inspect(resp))
							table.insert(messages_copy, {
								role = "tool",
								content = resp,
								tool_call_id = call_id,
								name = "weather",
							})
						end

						-- Debug: Show new message structure
						print(
							"Sending follow-up request with messages:\n" .. vim.inspect(messages_copy),
							vim.log.levels.DEBUG
						)

						-- Start new request with updated messages
						M.stream(model, messages_copy, callback, cleanup, tools)
					end)
				else
					cleanup()
				end
			end

			stream(data)
		end,
		cleanup = cleanup,
	})
end

function M.set_config(config)
	M.config = config
end

return M