local curl = require("plenary.curl")
local utils = require("llm_search.providers.utils")

local M = {}

M.api_url = "https://api.anthropic.com/v1/messages"
M.cache_enabled = true

-- Helper function to format tools for Anthropic API with caching
local function format_tools(tools, should_cache)
	if not tools or #tools == 0 then
		return {}
	end
	
	local formatted_tools = {}
	for i, tool in ipairs(tools) do
		local formatted_tool = {
			name = tool.name,
			description = tool.description,
			input_schema = tool.input_schema,
		}
		
		-- Add cache_control to the last tool if caching is enabled
		if should_cache and i == #tools then
			formatted_tool.cache_control = { type = "ephemeral" }
		end
		
		table.insert(formatted_tools, formatted_tool)
	end
	return formatted_tools
end

local function handle_tool_calls(tool_calls, tools, output_callback, final_callback)
	local pending = #tool_calls
	local responses = {}

	for _, call in ipairs(tool_calls) do
		for _, tool in ipairs(tools) do
			if call.name == tool.name then
				-- First, add tool call message to the chat
				local call_args
				if type(call.arguments) == "table" then
					call_args = vim.inspect(call.arguments)
				else
					call_args = tostring(call.arguments)
				end
				output_callback("\n\n[Tool Call]: " .. call.name .. "\n```json\n" .. call_args .. "\n```")
				
				-- Execute the tool
				tool.handler(call.arguments, function(response)
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
	local api_key = M.config.providers.anthropic.api_key
	-- Get the system message
	local system_message = vim.tbl_filter(function(message)
		return message.role == "system"
	end, messages)[1]
	-- Remove the system message from messages
	messages = vim.tbl_filter(function(message)
		return message.role ~= "system"
	end, messages)

	-- Set up headers with any beta headers if specified in the model
	local headers = {
		["Content-Type"] = "application/json",
		["x-api-key"] = api_key,
		["anthropic-version"] = "2023-06-01",
	}

	-- Add beta headers if specified in the model
	if model.params and model.params.beta_headers then
		for _, beta_header in ipairs(model.params.beta_headers) do
			headers["anthropic-beta"] = beta_header
		end
	end

	-- Format system message with caching
	local formatted_system = nil
	if system_message then
		if M.cache_enabled and system_message.content and system_message.content ~= "" then
			-- For caching, we need to convert the system message into an array format
			formatted_system = {
				{
					type = "text",
					text = system_message.content,
					cache_control = { type = "ephemeral" }
				}
			}
		else
			-- Regular system message (string format) when caching is disabled
			formatted_system = system_message.content
		end
	end

	-- Format messages with caching if enabled
	local formatted_messages = messages
	if M.cache_enabled then
		formatted_messages = format_messages(messages, true)
	end

	-- Prepare the request body
	local body = {
		model = model.name,
		messages = formatted_messages,
		max_tokens = 8192, -- default value
		system = formatted_system,
	}

	-- Override parameters from model.params if provided
	if model.params then
		-- Add any other parameters that might be in model.params
		for key, value in pairs(model.params) do
			if key ~= "beta_headers" then
				body[key] = value
			end
		end
	end

	curl.post(M.api_url, {
		headers = headers,
		body = vim.fn.json_encode(body),
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

-- Helper function to format messages with caching
local function format_messages(messages, should_cache)
	if not messages or #messages == 0 then
		return messages
	end
	
	local formatted_messages = vim.deepcopy(messages)
	
	-- Find the last user message to apply caching
	if should_cache then
		local last_user_msg_idx = nil
		for i = #formatted_messages, 1, -1 do
			if formatted_messages[i].role == "user" then
				last_user_msg_idx = i
				break
			end
		end
		
		-- If we found a user message, convert its content for caching if it's a simple string
		if last_user_msg_idx then
			local msg = formatted_messages[last_user_msg_idx]
			
			-- Convert simple string content to array format with cache_control
			if type(msg.content) == "string" then
				msg.content = {
					{
						type = "text",
						text = msg.content,
						cache_control = { type = "ephemeral" }
					}
				}
			-- Handle content that's already an array
			elseif type(msg.content) == "table" and #msg.content > 0 then
				-- Add cache_control to the last content block
				local last_content = msg.content[#msg.content]
				if type(last_content) == "table" and last_content.type == "text" then
					last_content.cache_control = { type = "ephemeral" }
				end
			end
		end
	end
	
	return formatted_messages
end

function M.stream(model, messages, callback, cleanup, tools, prev_system_message)
	local api_key = M.config.providers.anthropic.api_key
	-- Get the system message
	local system_message = prev_system_message
		or vim.tbl_filter(function(message)
			return message.role == "system"
		end, messages)[1]
	-- Remove the system message from messages
	messages = vim.tbl_filter(function(message)
		return message.role ~= "system"
	end, messages)
	local headers = {
		"Content-Type: application/json",
		"x-api-key: " .. api_key,
		"anthropic-version: 2023-06-01",
	}
	-- Add beta headers if specified in the model
	if model.params and model.params.beta_headers then
		for _, beta_header in ipairs(model.params.beta_headers) do
			table.insert(headers, "anthropic-beta: " .. beta_header)
		end
	end
	
	-- Format system message with caching
	local formatted_system = nil
	if system_message then
		if M.cache_enabled and system_message.content and system_message.content ~= "" then
			-- For caching, we need to convert the system message into an array format
			formatted_system = {
				{
					type = "text",
					text = system_message.content,
					cache_control = { type = "ephemeral" }
				}
			}
		else
			-- Regular system message (string format) when caching is disabled
			formatted_system = system_message.content
		end
	end
	
	-- Format messages with caching if enabled
	local formatted_messages = messages
	if M.cache_enabled then
		formatted_messages = format_messages(messages, true)
	end
	
	local body = {
		model = model.name,
		messages = formatted_messages,
		max_tokens = 8192,
		stream = true,
		system = formatted_system,
	}
	-- Override parameters from model.params if provided
	if model.params then
		-- Add any other parameters that might be in model.params
		for key, value in pairs(model.params) do
			if key ~= "beta_headers" then
				body[key] = value
			end
		end
	end
	-- Add tools to the request if provided
	if tools then
		body.tools = format_tools(tools, M.cache_enabled)
	end

	-- State tracking for tool calls
	local state = {
		tool_calls = {},
		current_tool_call = nil,
	}

	cleanup = cleanup or function() end -- Added safeguard

	local stream = function(data)
		if data then
			local lines = vim.split(data, "\n")
			for _, line in ipairs(lines) do
				if line:match("^event:") then
					local event_type = line:gsub("^event:%s*", "")
					-- Handle message stop events
					if event_type == "message_stop" then
						if #state.tool_calls > 0 then
							handle_tool_calls(state.tool_calls, tools, callback, function(tool_responses)
								-- Create a message with Claude's original tool uses
								local claude_tool_use_message = {
									role = "assistant",
									content = {},
								}

								-- Add all tool uses to the assistant message
								for _, call in ipairs(state.tool_calls) do
									table.insert(claude_tool_use_message.content, {
										type = "tool_use",
										id = call.id,
										name = call.name,
										input = call.arguments,
									})
								end

								-- Create user message containing tool responses
								local user_tool_result_message = {
									role = "user",
									content = {},
								}

								-- Add tool results to user message
								for tool_id, response in pairs(tool_responses) do
									table.insert(user_tool_result_message.content, {
										type = "tool_result",
										tool_use_id = tool_id,
										content = response,
									})
								end

								-- Build complete new message list
								local new_messages = vim.deepcopy(messages)
								table.insert(new_messages, claude_tool_use_message) -- Claude's tool use
								table.insert(new_messages, user_tool_result_message) -- User tool results

								-- Add back the original system message if it exists
								if system_message then
									new_messages = vim.list_extend({ system_message }, new_messages)
								end

								-- Start new request with full history
								M.stream(model, new_messages, callback, cleanup, tools)
							end)
						else
							cleanup()
						end
					end
				end

				if line:match("^data:") then
					local json_str = line:gsub("^data:%s*", "")
					if json_str == "[DONE]" then
						return
					end

					local result = vim.json.decode(json_str)
					if not result then
						return
					end

					-- Handle different content block types
					if result.type == "content_block_start" then
						if result.content_block and result.content_block.type == "tool_use" then
							state.current_tool_call = {
								id = result.content_block.id,
								name = result.content_block.name,
								index = result.index,
								input_parts = {},
							}
						end
					elseif result.type == "content_block_delta" then
						if state.current_tool_call and result.delta.type == "input_json_delta" then
							table.insert(state.current_tool_call.input_parts, result.delta.partial_json)
						end
					elseif result.type == "content_block_stop" then
						if state.current_tool_call then
							-- Parse accumulated JSON input
							local input_json = table.concat(state.current_tool_call.input_parts)
							local ok, parsed = pcall(vim.json.decode, input_json)
							if ok then
								table.insert(state.tool_calls, {
									name = state.current_tool_call.name,
									arguments = parsed,
									id = state.current_tool_call.id,
								})
							end
							state.current_tool_call = nil
						end
					end

					-- Handle text deltas and final message stop
					if result.delta and result.delta.text then
						callback(result.delta.text)
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
	-- Set caching based on config if provided
	if config and config.providers and config.providers.anthropic and config.providers.anthropic.cache_prompts ~= nil then
		M.cache_enabled = config.providers.anthropic.cache_prompts
	end
end

-- Function to enable or disable caching
function M.toggle_cache(enabled)
	if enabled ~= nil then
		M.cache_enabled = enabled
	else
		M.cache_enabled = not M.cache_enabled
	end
	return M.cache_enabled
end

return M