local job = require("plenary.job")

local M = {}

function M.run_curl_with_streaming(opts)
	-- Default options
	opts = vim.tbl_extend("keep", opts or {}, {
		url = "",
		method = "POST",
		headers = {},
		body = nil,
		on_chunk = nil,
		cleanup = nil,
	})

	local args = {
		"-s", -- silent mode
		"-N", -- disable buffering
		"-X",
		opts.method,
	}

	-- Add custom headers
	for _, header in ipairs(opts.headers) do
		table.insert(args, "-H")
		table.insert(args, header)
	end

	-- Add body if present
	if opts.body then
		table.insert(args, "-d")
		table.insert(args, vim.json.encode(opts.body))
	end

	-- Add URL
	table.insert(args, opts.url)

	local job_ = job:new({
		command = "curl",
		args = args,
		on_stdout = function(_, data)
			if opts.on_chunk then
				opts.on_chunk(data)
			end
		end,
		on_stderr = function(_, data)
			vim.notify("Error: " .. data, vim.log.levels.ERROR)
			print("Error: " .. data)
		end,
		on_exit = function()
			if opts.cleanup then
				opts.cleanup()
			end
		end,
	})

	job_:start()
	return job_
end

return M
