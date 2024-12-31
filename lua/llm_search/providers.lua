local curl = require("plenary.curl")
local Job = require('plenary.job')

local function run_curl_with_streaming(opts)
    -- Default options
    opts = vim.tbl_extend("keep", opts or {}, {
        url = "",
        method = "POST",
        headers = {},
        body = nil,
        on_chunk = nil,
        cleanup = nil
    })

    local args = {
        '-s', -- silent mode
        '-N', -- disable buffering
        '-X', opts.method,
        '-H', 'Content-Type: application/json'
    }

    -- Add custom headers
    for _, header in ipairs(opts.headers) do
        table.insert(args, '-H')
        table.insert(args, header)
    end

    -- Add body if present
    if opts.body then
        table.insert(args, '-d')
        table.insert(args, vim.json.encode(opts.body))
    end

    -- Add URL
    table.insert(args, opts.url)

    local job = Job:new({
        command = 'curl',
        args = args,
        on_stdout = function(_, data)
            if opts.on_chunk then
                opts.on_chunk(data)
            end
        end,
        on_stderr = function(_, data)
            vim.notify("Error: " .. data, vim.log.levels.ERROR)
        end,
        on_exit = function()
            if opts.cleanup then
                opts.cleanup()
            end
        end,
    })

    job:start()
    return job
end

local M = {}

M.fireworks = {
    api_url = "https://api.fireworks.ai/inference/v1/chat/completions",

    request = function(model, messages, callback)
        local api_key = M.config.providers.fireworks.api_key
        curl.post(M.fireworks.api_url, {
            headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer " .. api_key
            },
            body = vim.fn.json_encode({
                model = model.name,
                messages = messages
            }),
            callback = vim.schedule_wrap(function(response)
                if response.status ~= 200 then
                    vim.notify("API request failed with status " .. response.status .. "\n" .. response.body,
                        vim.log.levels.ERROR)
                    return
                end
                local result = vim.json.decode(response.body)
                callback(result.choices[1].message.content)
            end)
        })
    end,

    stream = function(model, messages, callback, cleanup)
        local api_key = M.config.providers.fireworks.api_key
        local headers = {
            "Content-Type: application/json",
            "Authorization: Bearer " .. api_key
        }
        local body = {
            model = model.name,
            messages = messages,
            stream = true
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
        run_curl_with_streaming({
            url = M.fireworks.api_url,
            method = "POST",
            headers = headers,
            body = body,
            on_chunk = stream,
            cleanup = cleanup
        })
    end
}

M.anthropic = {
    api_url = "https://api.anthropic.com/v1/messages",

    request = function(model, messages, callback)
        local api_key = M.config.providers.anthropic.api_key
        -- Get the system message
        local system_message = vim.tbl_filter(function(message)
            return message.role == "system"
        end, messages)[1]
        -- Remove the system message from messages
        messages = vim.tbl_filter(function(message)
            return message.role == "user"
        end, messages)
        curl.post(M.anthropic.api_url, {
            headers = {
                ["Content-Type"] = "application/json",
                ["x-api-key"] = api_key,
                ["anthropic-version"] = "2023-06-01"
            },
            body = vim.fn.json_encode({
                model = model.name,
                messages = messages,
                max_tokens = 8192,
                system = system_message.content
            }),
            callback = vim.schedule_wrap(function(response)
                if response.status ~= 200 then
                    vim.notify("API request failed with status " .. response.status .. "\n" .. response.body,
                        vim.log.levels.ERROR)
                    return
                end
                local result = vim.json.decode(response.body)
                callback(result.content[1].text)
            end)
        })
    end,

    stream = function(model, messages, callback, cleanup)
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
            "anthropic-version: 2023-06-01"
        }
        local body = {
            model = model.name,
            messages = messages,
            max_tokens = 8192,
            stream = true,
            system = system_message.content
        }
        local stream = function(data)
            if data then
                local lines = vim.split(data, "\n")
                for _, line in ipairs(lines) do
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
        run_curl_with_streaming({
            url = M.anthropic.api_url,
            method = "POST",
            headers = headers,
            body = body,
            on_chunk = stream,
            cleanup = cleanup
        })
    end
}

M.openai = {
    api_url = "https://api.openai.com/v1/chat/completions",

    request = function(model, messages, callback)
        local api_key = M.config.providers.openai.api_key
        curl.post(M.openai.api_url, {
            headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer " .. api_key
            },
            body = vim.fn.json_encode({
                model = model.name,
                messages = messages,
                max_tokens = 1024
            }),
            callback = vim.schedule_wrap(function(response)
                if response.status ~= 200 then
                    vim.notify("API request failed with status " .. response.status .. "\n" .. response.body,
                        vim.log.levels.ERROR)
                    return
                end
                local result = vim.json.decode(response.body)
                callback(result.choices[1].message.content)
            end)
        })
    end,

    stream = function(model, messages, callback, cleanup)
        local api_key = M.config.providers.openai.api_key
        local headers = {
            "Content-Type: application/json",
            "Authorization: Bearer " .. api_key
        }
        local body = {
            model = model.name,
            messages = messages,
            max_tokens = 1024,
            stream = true
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
        run_curl_with_streaming({
            url = M.openai.api_url,
            method = "POST",
            headers = headers,
            body = body,
            on_chunk = stream,
            cleanup = cleanup,
        })
    end
}

M.set_config = function(config)
    M.config = config
end


--[[
-- Groq API
--
curl -X POST "https://api.groq.com/openai/v1/chat/completions" \
     -H "Authorization: Bearer $GROQ_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"messages": [{"role": "user", "content": "Explain the importance of fast language models"}], "model": "llama3-8b-8192"}'
--
--
--k
--]]

M.groq = {
    api_url = "https://api.groq.com/openai/v1/chat/completions",

    request = function(model, messages, callback)
        local api_key = M.config.providers.groq.api_key
        curl.post(M.groq.api_url, {
            headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer " .. api_key
            },
            body = vim.fn.json_encode({
                model = model.name,
                messages = messages,
                max_tokens = 1024
            }),
            callback = vim.schedule_wrap(function(response)
                if response.status ~= 200 then
                    vim.notify("API request failed with status " .. response.status .. "\n" .. response.body,
                        vim.log.levels.ERROR)
                    return
                end
                local result = vim.json.decode(response.body)
                callback(result.choices[1].message.content)
            end)
        })
    end,

    stream = function(model, messages, callback, cleanup)
        local api_key = M.config.providers.groq.api_key
        local headers = {
            "Content-Type: application/json",
            "Authorization: Bearer " .. api_key
        }
        local body = {
            model = model.name,
            messages = messages,
            max_tokens = 1024,
            stream = true
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
        run_curl_with_streaming({
            url = M.groq.api_url,
            method = "POST",
            headers = headers,
            body = body,
            on_chunk = stream,
            cleanup = cleanup,
        })
    end
}

return M
