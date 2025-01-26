local M = {}

function M.find_position_from_snippet(file_content, marked_snippet)
	-- Remove the marker and get raw text to match
	local raw_snippet = marked_snippet:gsub("§", "")
	local symbol = marked_snippet:match("§([%w_]+)§")

	if not symbol then
		return nil
	end

	-- Find position where snippet appears in content
	local start_pos = file_content:find(raw_snippet, 1, true)
	if not start_pos then
		return nil
	end

	-- Find symbol position relative to snippet
	local symbol_offset = marked_snippet:find("§" .. symbol)

	-- Calculate final position
	local lines = vim.split(file_content:sub(1, start_pos + symbol_offset - 1), "\n")

	return {
		line = #lines - 1,
		character = #lines[#lines] - 1,
	}
end

function M.get_definition_at_snippet(file_path, marked_snippet, callback)
	vim.schedule(function()
		-- 1. File check in main thread
		local file_exists = vim.fn.filereadable(file_path) == 1
		if not file_exists then
			vim.schedule(function()
				callback(nil, "File not found")
			end)
			return
		end

		-- 2. Buffer operations protected in main thread
		local bufnr = vim.fn.bufnr(file_path, true)
		vim.fn.bufload(bufnr)

		-- 3. Get content from buffer
		local buffer_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

		-- 4. Find position using pure Lua
		local pos = M.find_position_from_snippet(buffer_content, marked_snippet)
		if not pos then
			vim.schedule(function()
				callback(nil, "Snippet not found")
			end)
			return
		end

		-- 5. Prepare LSP request
		local params = {
			textDocument = { uri = vim.uri_from_fname(file_path) },
			position = pos,
		}

		-- 6. Final LSP request with callback
		vim.lsp.buf_request(bufnr, "textDocument/definition", params, function(err, result)
			-- Wrap callback in schedule to ensure thread safety
			vim.schedule(function()
				callback(err, result)
			end)
		end)
	end)
end

function M.get_references_at_snippet(file_path, marked_snippet, callback)
	vim.schedule(function()
		-- 1. File check in main thread
		local file_exists = vim.fn.filereadable(file_path) == 1
		if not file_exists then
			vim.schedule(function()
				callback(nil, "File not found")
			end)
			return
		end

		-- 2. Buffer operations protected in main thread
		local bufnr = vim.fn.bufnr(file_path, true)
		vim.fn.bufload(bufnr)

		-- 3. Get content from buffer
		local buffer_content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

		-- 4. Find position using pure Lua
		local pos = M.find_position_from_snippet(buffer_content, marked_snippet)
		if not pos then
			vim.schedule(function()
				callback(nil, "Snippet not found")
			end)
			return
		end

		-- 5. Prepare LSP request with reference context
		local params = {
			textDocument = { uri = vim.uri_from_fname(file_path) },
			position = pos,
			context = {
				includeDeclaration = true,
			},
		}

		-- 6. Final LSP request with callback
		vim.lsp.buf_request(bufnr, "textDocument/references", params, function(err, result)
			-- Wrap callback in schedule to ensure thread safety
			vim.schedule(function()
				callback(err, result)
			end)
		end)
	end)
end

-- Add this test function to your lua/llm_search/context_suppliers/lsp.lua
function M.debug_definition_to_clipboard()
	local params = {
		textDocument = { uri = vim.uri_from_fname(vim.fn.expand("%:p")) },
		position = { line = vim.fn.line(".") - 1, character = vim.fn.col(".") - 1 },
	}

	print("Requesting definition..., params; ", vim.inspect(params))

	vim.lsp.buf_request(0, "textDocument/definition", params, function(err, result)
		local result_str = vim.inspect(result)
		vim.fn.setreg("*", vim.inspect(err) .. "    " .. result_str)
		print("Definition result copied to clipboard register (*)")
	end)
end

return M
