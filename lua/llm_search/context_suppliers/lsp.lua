-- TODO Not exactly a context supplier tbh
-- Special marker for the symbol: §

-- LSP Context Supplier Query Syntax
-- ```lspquery
-- textDocument/definition
-- path/to/file.tsx
-- options: wholeFile, onlySymbol
--
-- local function hello()
--   §print§('hi')
-- ```
--
-- There is a double \n after metadata and before the snippet
-- § is a special marker for the symbol

local M = {}

local llm_prompt_for_query_syntax = [[
When you want to run an LSP request, use the following format:

Start a markdown code block with 'lspquery' to indicate the query syntax.
First line: LSP method (e.g. 'textDocument/definition', 'textDocument/references')
Second line: Path to the file where the symbol is located
Third line: Options (optional)
   - wholeFile: include the entire file contents
   - onlySymbol: focus only on the marked symbol

After two newlines, provide the code snippet with the symbol marked using § characters.
You don't have to provide the whole code in the snippet, just make sure it is unique in the file.
If it is not unique the first occurrence will be used.
The § character marks the symbol you want to query. The symbol must be wrapped with § on both sides.

Example:
```lspquery
textDocument/definition
src/components/Button.tsx
options: wholeFile

const Button = () => {
  return <$button$>Click me</button>
}
```
]]

local function get_lsp_queries_from_message(message_text)
	local queries = {}

	-- Find all lspquery code blocks
	for block in message_text:gmatch("```lspquery\n(.-)\n```") do
		local lines = {}
		for line in block:gmatch("[^\n]+") do
			table.insert(lines, line)
		end

		-- Parse query parts
		local query = {
			method = lines[1],
			file_path = lines[2],
			options = {},
			snippet = nil,
		}

		-- Parse options if present
		if lines[3] and lines[3]:match("^options:") then
			local options = lines[3]:gsub("options:", "")
			for option in options:gmatch("%w+") do
				query.options[option] = true
			end
			-- Skip options line
			table.remove(lines, 3)
		end

		-- Get snippet (everything after two newlines)
		local snippet = table.concat({ select(4, unpack(lines)) }, "\n")
		query.snippet = snippet:match("^[\n\r]*(.-)[\n\r]*$") -- Trim whitespace

		table.insert(queries, query)
	end

	return queries
end

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

function M.get_definition_at_snippet(file_content, marked_snippet)
	local pos = M.find_position_from_snippet(file_content, marked_snippet)
	if not pos then
		return "Snippet not found"
	end

	local params = {
		textDocument = { uri = vim.uri_from_bufnr(0) },
		position = pos,
	}

	vim.lsp.buf_request(0, "textDocument/definition", params, function(err, result)
		if err then
			return err
		end
		return result
	end)
end

return M
