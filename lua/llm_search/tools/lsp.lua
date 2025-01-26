return {
	lsp_query = {
		name = "lsp_query",
		description = "Execute LSP requests to understand code context",
		input_schema = {
			type = "object",
			properties = {
				method = {
					type = "string",
					description = "LSP method to execute (e.g. textDocument/definition)",
					enum = { "textDocument/definition", "textDocument/references" },
				},
				file_path = {
					type = "string",
					description = "Absolute path to the file containing the symbol",
				},
				options = {
					type = "array",
					items = {
						type = "string",
						enum = { "wholeFile", "onlySymbol", "parentStatement" },
					},
					description = "onlySymbol will get you only the symbol content, wholeFile will get you the whole file content, parentStatement will try to get you the largest parent statement of the symbol. rule of thumb is, if you are looking up definitions try to use onlySymbol. If you are looking up references, try to use parentStatement. only use wholeFile if really neeeded.",
				},
				marked_snippet = {
					type = "string",
					description = "Code snippet with § markers around the target symbol",
				},
			},
			required = { "method", "file_path", "marked_snippet" },
		},
		handler = function(args, callback)
			local lsp = require("llm_search.context_suppliers.lsp")

			local function process_results(result, options)
				local pending = 0
				local results = {}

				local function check_done()
					pending = pending - 1
					if pending == 0 then
						if #results == 0 then
							callback("No readable content found")
						else
							callback("Results:\n" .. table.concat(results, "\n\n---\n\n"))
						end
					end
				end

				for _, location in ipairs(result) do
					pending = pending + 1

					-- Handle different location types
					local target_uri = location.uri or location.targetUri
					local range = location.range or location.targetRange
					if not (target_uri and range) then
						pending = pending - 1
						goto continue
					end

					local file_path_abs = vim.uri_to_fname(target_uri)
					local file_path_rel = vim.fn.fnamemodify(file_path_abs, ":~:.")

					vim.schedule(function()
						vim.uv.fs_open(file_path_abs, "r", 438, function(open_err, fd)
							if open_err then
								table.insert(results, string.format("Error opening %s: %s", file_path_rel, open_err))
								return check_done()
							end

							vim.uv.fs_fstat(fd, function(stat_err, stat)
								if stat_err then
									table.insert(results, string.format("Error stat %s: %s", file_path_rel, stat_err))
									vim.uv.fs_close(fd)
									return check_done()
								end

								vim.uv.fs_read(fd, stat.size, 0, function(read_err, data)
									vim.uv.fs_close(fd)

									if read_err then
										table.insert(
											results,
											string.format("Error reading %s: %s", file_path_rel, read_err)
										)
										return check_done()
									end

									local content = vim.split(data, "\n")
									local snippet = ""

									vim.schedule(function()
										if vim.tbl_contains(options or {}, "wholeFile") then
											snippet = data or "<No file content available>"
										elseif vim.tbl_contains(options or {}, "parentStatement") then
											local filetype = vim.filetype.match({ filename = file_path_abs })
											local lang = filetype and vim.treesitter.language.get_lang(filetype) or nil
											if not lang then
												snippet = "<Unable to determine language>"
											else
												local ok, parent_stat_node = pcall(function()
													local parser = vim.treesitter.get_string_parser(data, lang)
													local tree = parser:parse()[1]
													if not tree then
														return nil, "Parse error"
													end
													local root = tree:root()

													local lsp_start = range.start
													local start_row = lsp_start.line
													local start_col = lsp_start.character
													local end_row = range["end"].line
													local end_col = range["end"].character

													local target_node = root:named_descendant_for_range(
														start_row,
														start_col,
														end_row,
														end_col
													)
													if not target_node then
														return nil, "No node found for range"
													end

													local current_node = target_node
													local parent_stat = nil
													local last_under_200 = nil

													while current_node do
														local s_row, _, e_row = current_node:range()
														local line_count = e_row - s_row + 1

														-- Break if node exceeds line limit
														if line_count > 200 then
															break
														end

														-- Check if current node is a direct child of the root
														if current_node:parent() == root then
															parent_stat = current_node
															break
														end

														last_under_200 = current_node
														current_node = current_node:parent()
													end

													-- Fallback to the last node under 200 lines if no direct child found
													if not parent_stat then
														parent_stat = last_under_200
													end

													if not parent_stat then
														return nil, "No parent statement found within line limit"
													end

													local s_row, s_col, e_row, e_col = parent_stat:range()
													return {
														start_row = s_row,
														start_col = s_col,
														end_row = e_row,
														end_col = e_col,
													}
												end)

												if ok and parent_stat_node then
													local s_row = parent_stat_node.start_row
													local s_col = parent_stat_node.start_col
													local e_row = parent_stat_node.end_row
													local e_col = parent_stat_node.end_col

													local lines_snippet = {}
													for row = s_row, e_row do
														local row_in_content = row + 1 -- Convert to 1-based index
														if row_in_content > #content then
															break
														end

														local line_str = content[row_in_content]
														local from_col, to_col

														if row == s_row and row == e_row then
															from_col = s_col + 1
															to_col = e_col
														elseif row == s_row then
															from_col = s_col + 1
															to_col = #line_str
														elseif row == e_row then
															from_col = 1
															to_col = e_col
														else
															from_col = 1
															to_col = #line_str
														end

														if from_col > to_col then
															table.insert(lines_snippet, "")
														else
															local part = string.sub(line_str, from_col, to_col)
															table.insert(lines_snippet, part)
														end
													end

													if #lines_snippet > 0 then
														snippet = table.concat(lines_snippet, "\n")
													else
														snippet = "<No snippet extracted>"
													end
												else
													snippet = "<Error finding parent statement: "
														.. tostring(parent_stat_node)
														.. ">"
												end
											end
										else
											-- Original 'onlySymbol' logic
											local start = math.max(range.start.line + 1, 1)
											local end_ln = math.min(range["end"].line + 1, #content)

											if start <= end_ln then
												snippet = table.concat(vim.list_slice(content, start, end_ln), "\n")
											else
												snippet = "<No symbol content available>"
											end
										end

										table.insert(
											results,
											string.format("File: %s\nContent:\n%s", file_path_rel, snippet)
										)
										check_done()
									end)
								end)
							end)
						end)
					end)
					::continue::
				end
			end
			if args.method == "textDocument/definition" then
				lsp.get_definition_at_snippet(args.file_path, args.marked_snippet, function(err, result)
					if err then
						return callback("LSP Error: " .. tostring(err))
					end
					if not result or vim.tbl_isempty(result) then
						return callback("No definition found")
					end

					process_results(result, args.options)
				end)
			elseif args.method == "textDocument/references" then
				lsp.get_references_at_snippet(args.file_path, args.marked_snippet, function(err, result)
					if err then
						return callback("LSP Error: " .. tostring(err))
					end
					if not result or vim.tbl_isempty(result) then
						return callback("No references found")
					end
					process_results(result, args.options)
				end)
			else
				callback("Unsupported LSP method: " .. (args.method or ""))
			end
		end,
	},
}
