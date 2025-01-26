local curl = require("plenary.curl")
local utils = require("llm_search.providers.utils")

local M = {}

M.api_url = "https://api.openai.com/v1/chat/completions"

function M.request(model, messages, callback)
	local api_key = M.config.providers.openai.api_key
	curl.post(M.api_url, {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. api_key,
		},
		body = vim.fn.json_encode({
			model = model.name,
			messages = messages,
			max_tokens = 1024,
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
			callback(result.choices[1].message.content)
		end),
	})
end

function M.stream(model, messages, callback, cleanup)
	local api_key = M.config.providers.openai.api_key
	local headers = {
		"Content-Type: application/json",
		"Authorization: Bearer " .. api_key,
	}
	local body = {
		model = model.name,
		messages = messages,
		max_tokens = 1024,
		stream = true,
	}
	local stream = function(data)
		if data then
			local lines = vim.split(data, "\n")
			for _, line in ipairs(lines) do
				if line:match("^data:") then
					local json_str = line:gsub("^data:%s*", "")
					if json_str ~= "[DONE]" then
						local result = vim.json.decode(json_str)
						if result.choices and result.choices[1].delta and result.choices[1].delta.content then
							callback(result.choices[1].delta.content)
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
