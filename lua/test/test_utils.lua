local M = {}

-- Initialize mock vim environment
function M.init_vim_mock()
	_G.vim = {
		inspect = function(value)
			if type(value) == "table" then
				local result = "{"
				local first = true
				for k, v in pairs(value) do
					if not first then
						result = result .. ","
					end
					if type(k) == "string" then
						result = result .. k .. "="
					end
					if type(v) == "table" then
						result = result .. vim.inspect(v)
					else
						result = result .. tostring(v)
					end
					first = false
				end
				return result .. "}"
			else
				return tostring(value)
			end
		end,
		split = function(str, sep, opts)
			if sep == "\n" then
				local parts = {}
				local start = 1
				local plain = opts and opts.plain

				while true do
					local pos = string.find(str, "\n", start, plain)
					if not pos then
						table.insert(parts, string.sub(str, start))
						break
					end
					table.insert(parts, string.sub(str, start, pos - 1))
					start = pos + 1
				end
				return parts
			end
			-- Fall back to simple pattern matching for other cases
			local parts = {}
			for part in string.gmatch(str, "[^" .. sep .. "]+") do
				table.insert(parts, part)
			end
			return parts
		end,
		api = {
			nvim_buf_get_lines = function()
				return {}
			end,
			nvim_get_current_buf = function()
				return 1
			end,
			nvim_win_get_cursor = function()
				return { 1, 0 }
			end,
		},
		fn = {
			getqflist = function()
				-- Return mock quickfix items
				return {
					{
						bufnr = 1,
						lnum = 2,
						col = 1,
						text = "Error: undefined variable 'foo'",
						type = "E",
					},
					{
						bufnr = 1,
						lnum = 5,
						col = 1,
						text = "Warning: unused variable 'bar'",
						type = "W",
					},
				}
			end,
		},
		notify = function(message, level)
			print(string.format("NOTIFY [%s]: %s", level, message))
		end,
		log = {
			levels = {
				WARN = "WARN",
				ERROR = "ERROR",
			},
		},
	}
end

-- Assert utilities
function M.assert_equals(expected, got, message)
	local formatted_message = string.format(
		"%s\nExpected: %s\nReceived: %s",
		message or "Values don't match",
		tostring(expected),
		tostring(got)
	)
	assert(expected == got, formatted_message)
end

function M.assert_length(expected_length, table_or_string, message)
	local length = type(table_or_string) == "table" and #table_or_string or string.len(table_or_string)
	local formatted_message = string.format(
		"%s\nExpected length: %d\nReceived length: %d",
		message or "Length doesn't match",
		expected_length,
		length
	)
	assert(expected_length == length, formatted_message)
end

function M.assert_not_nil(value, message)
	local formatted_message = message or "Value is nil"
	assert(value ~= nil, formatted_message)
end

function M.assert_nil(value, message)
	local formatted_message = message or "Value is not nil"
	assert(value == nil, formatted_message)
end

return M
