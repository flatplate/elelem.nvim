local io_utils = require("llm_search.io_utils")
local highlights = require("llm_search.highlights")

-- Helper function to create a colorized inline diff for confirmation dialogues
local function create_inline_diff(original, replacement, max_lines)
	-- Split texts into lines
	local old_lines = vim.split(original or "", "\n")
	local new_lines = vim.split(replacement or "", "\n")
	
	-- Calculate line-by-line diffs
	local result = {}
	local shown_lines = 0
	local max_to_show = max_lines or 10 -- Default to showing 10 lines
	
	-- Use ANSI color codes for terminal output
	table.insert(result, "Diff:")
	shown_lines = shown_lines + 1
	
	-- Show a subset of removed lines if there are too many
	local old_start = 1
	if #old_lines > max_to_show / 2 then
		old_start = #old_lines - math.floor(max_to_show / 2) + 1
	end
	
	-- Add removed lines with red color
	for i = old_start, #old_lines do
		if shown_lines >= max_to_show then break end
		table.insert(result, "\27[31m- " .. old_lines[i] .. "\27[0m") -- Red text
		shown_lines = shown_lines + 1
	end
	
	-- Add added lines with green color
	local new_start = 1
	if #new_lines > max_to_show / 2 then
		new_start = math.floor(max_to_show / 2) - 1
	end
	
	for i = new_start, math.min(#new_lines, new_start + math.floor(max_to_show / 2)) do
		if shown_lines >= max_to_show then break end
		table.insert(result, "\27[32m+ " .. new_lines[i] .. "\27[0m") -- Green text
		shown_lines = shown_lines + 1
	end
	
	return table.concat(result, "\n")
end

local tools = {
	cli = {
		name = "execute_command",
		description = "Execute a shell command and return the output",
		input_schema = {
			type = "object",
			properties = {
				command = {
					type = "string",
					description = "The shell command to execute",
				},
				timeout = {
					type = "number",
					description = "Optional timeout in milliseconds (default: 10000)",
				},
			},
			required = { "command" },
		},
		handler = function(args, callback)
			-- Always wrap UI operations in vim.schedule
			vim.schedule(function()
				local command = args.command
				local timeout = args.timeout or 10000 -- Default 10 second timeout
				
				-- Sanitize command to prevent dangerous operations
				if command:match("^%s*rm%s+") or command:match("sudo") then
					return callback("Error: Potentially dangerous command rejected for security reasons")
				end
				
				-- Create a simple popup for confirmation
				local should_run = vim.fn.confirm("Execute command: " .. command, "&Yes\n&No", 2) == 1
				
				if should_run then
					vim.api.nvim_echo({{ "Executing: " .. command, "WarningMsg" }}, false, {})
					
					io_utils.execute_command(command, timeout, function(err, stdout, stderr)
						vim.schedule(function()
							if err then
								callback("Error executing command: " .. tostring(err) .. "\n" .. (stderr or ""))
							else
								local result = stdout
								if stderr and stderr ~= "" then
									result = result .. "\n--- stderr ---\n" .. stderr
								end
								
								callback(result)
							end
						end)
					end)
				else
					callback("Command execution cancelled by user")
				end
			end)
		end,
	},
    
    replace_with_diff = {
        name = "replace_file",
        description = "Replace an entire file with new content, showing a diff in a floating window before confirming the change.",
        input_schema = {
            type = "object",
            properties = {
                file_path = {
                    type = "string",
                    description = "Absolute path to the file to replace",
                },
                content = {
                    type = "string",
                    description = "The new content for the file",
                },
                show_diff = {
                    type = "boolean",
                    description = "Whether to show a diff before writing the file (default: true)",
                },
            },
            required = { "file_path", "content" },
        },
        handler = function(args, callback)
            vim.schedule(function()
                local file_path = args.file_path
                local new_content = args.content
                local show_diff = args.show_diff ~= false -- Default to true
                
                -- Try to read the file content
                local ok, original_content
                ok, original_content = pcall(function()
                    local file = io.open(file_path, "r")
                    if not file then
                        return ""
                    end
                    local content = file:read("*all")
                    file:close()
                    return content or ""
                end)
                
                if not ok then
                    original_content = ""
                end
                
                -- Check if content is actually different
                if original_content == new_content then
                    return callback("No changes needed - new content is identical to current file.")
                end
                
                -- Generate diff if requested
                if show_diff then
                    -- Generate diff
                    local diff_content = highlights.generate_diff(original_content, new_content)
                    
                    -- Create a temporary buffer for the diff
                    local bufnr = vim.api.nvim_create_buf(false, true)
                    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
                    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
                    vim.api.nvim_buf_set_option(bufnr, "filetype", "diff")
                    
                    -- Set the diff content
                    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(diff_content, "\n"))
                    
                    -- Create a floating window for the diff
                    local width = vim.api.nvim_get_option("columns")
                    local height = vim.api.nvim_get_option("lines")
                    local win_width = math.floor(width * 0.8)
                    local win_height = math.floor(height * 0.8)
                    local row = math.floor((height - win_height) / 2)
                    local col = math.floor((width - win_width) / 2)
                    
                    local win_opts = {
                        relative = "editor",
                        width = win_width,
                        height = win_height,
                        row = row,
                        col = col,
                        style = "minimal",
                        border = "rounded",
                        title = "Diff Preview: " .. vim.fn.fnamemodify(file_path, ":t"),
                        title_pos = "center",
                    }
                    
                    local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
                    
                    -- Set window-specific options
                    vim.api.nvim_win_set_option(winid, "wrap", false)
                    vim.api.nvim_win_set_option(winid, "cursorline", true)
                    
                    -- Add a keybinding to close the floating window with 'q'
                    vim.api.nvim_buf_set_keymap(bufnr, "n", "q", 
                        ":lua vim.api.nvim_win_close(" .. winid .. ", true)<CR>", 
                        { noremap = true, silent = true }
                    )
                    
                    -- Prompt for confirmation
                    local choice = vim.fn.confirm(
                        "Apply these changes to " .. file_path .. "?",
                        "&Yes\n&No", 
                        2
                    )
                    
                    -- Close the diff window
                    if vim.api.nvim_win_is_valid(winid) then
                        vim.api.nvim_win_close(winid, true)
                    end
                    
                    if choice ~= 1 then
                        return callback("Changes rejected by user")
                    end
                end
                
                -- Write the changes to the file
                local success = pcall(function()
                    local file = io.open(file_path, "w")
                    if not file then
                        error("Could not open file for writing: " .. file_path)
                    end
                    file:write(new_content)
                    file:close()
                end)
                
                if not success then
                    return callback("Error: Failed to write to " .. file_path)
                end
                
                callback("✅ File successfully replaced: " .. file_path .. "\n(Diff was shown before applying changes)")
            end)
        end
    },
	
	replace = {
		name = "batch_replace",
		description = "Replace strings across multiple files with confirmation. For each file, provide a list of replacements with 'from' and 'to' strings. The tool will try to match even when whitespace differs. The user will be shown a diff and asked to confirm each change.",
		input_schema = {
			type = "object",
			properties = {
				files = {
					type = "array",
					description = "Array of file objects that each contain replacements to be made",
					items = {
						type = "object",
						properties = {
							path = {
								type = "string",
								description = "Absolute path to the file",
							},
							replacements = {
								type = "array",
								description = "List of replacements to make in this file",
								items = {
									type = "object",
									properties = {
										from = {
											type = "string",
											description = "The string to be replaced (must be unique enough to identify the correct location)",
										},
										to = {
											type = "string",
											description = "The string to replace it with",
										},
									},
									required = { "from", "to" },
								},
							},
						},
						required = { "path", "replacements" },
					},
				},
			},
			required = { "files" },
		},
		handler = function(args, callback)
			-- Validate input
			if not args.files or #args.files == 0 then
				return callback("Error: No files specified for replacement")
			end
			
			-- Helper function to normalize whitespace in a string while preserving newlines
			local function normalize_whitespace(str)
				-- Replace tabs and multiple spaces with a single space, but keep newlines
				local normalized = str:gsub("[ \t]+", " ")
				-- Trim spaces at the beginning and end of each line
				normalized = normalized:gsub("\n[ \t]+", "\n")
				normalized = normalized:gsub("[ \t]+\n", "\n")
				-- Trim leading/trailing spaces
				normalized = normalized:gsub("^[ \t]+", ""):gsub("[ \t]+$", "")
				return normalized
			end
			
			vim.schedule(function()
				-- Process each file in sequence
				local results = {}
				local function process_file(file_index)
					if file_index > #args.files then
						-- All files processed, return results
						callback(table.concat(results, "\n\n"))
						return
					end
					
					local file_info = args.files[file_index]
					local file_path = file_info.path
					local replacements = file_info.replacements
					
					-- Read the file content
					local ok, file_content = pcall(vim.fn.readfile, file_path)
					if not ok then
						table.insert(results, "Error reading " .. file_path .. ": File not found or not readable")
						process_file(file_index + 1)
						return
					end
					
					-- Join the lines to a string for easier diff generation
					local content = table.concat(file_content, "\n")
					local new_content = content
					
					-- Apply all replacements to create the new content
					for _, replacement in ipairs(replacements) do
						if not replacement.from or not replacement.to then
							table.insert(results, "Error in replacement for " .. file_path .. ": Missing from/to strings")
							process_file(file_index + 1)
							return
						end
						
						-- First try an exact match
						local exact_match = new_content:find(replacement.from, 1, true)
						local from_text = replacement.from
						local to_text = replacement.to
						local text_to_replace = nil
						
						if not exact_match then
							-- If exact match fails, try matching with normalized whitespace
							local normalized_content = normalize_whitespace(new_content)
							local normalized_pattern = normalize_whitespace(replacement.from)
							
							-- Find the pattern in the normalized content
							local start_pos, end_pos = normalized_content:find(normalized_pattern, 1, true)
							
							if start_pos then
								-- Found a match with normalized whitespace
								-- Now we need to extract the actual text from the original content
								
								-- Find the line where the match starts
								local lines = vim.split(new_content, "\n")
								local pattern_lines = vim.split(normalized_pattern, "\n")
								local pattern_line_count = #pattern_lines
								
								-- Find the start line by counting newlines up to start_pos
								local start_line = 1
								local chars_counted = 0
								for i, line in ipairs(vim.split(normalized_content:sub(1, start_pos), "\n")) do
									if i < #vim.split(normalized_content:sub(1, start_pos), "\n") then
										start_line = start_line + 1
										chars_counted = chars_counted + #line + 1 -- +1 for the newline
									end
								end
								
								-- Build a pattern to find the original text
								-- This uses the start/end of each line to be more precise
								local pattern_parts = {}
								for i, line in ipairs(pattern_lines) do
									if #line > 0 then
										local escaped_line = line:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
										if i == 1 then
											-- First line - match from beginning of line or with leading whitespace
											table.insert(pattern_parts, "()[%s]*" .. escaped_line:gsub("^%s+", ""))
										elseif i == #pattern_lines then
											-- Last line - match until end of line or with trailing whitespace
											table.insert(pattern_parts, escaped_line:gsub("%s+$", "") .. "[%s]*()")
										else
											-- Middle lines - match with flexible whitespace
											table.insert(pattern_parts, escaped_line)
										end
									else
										-- Empty lines just match themselves
										table.insert(pattern_parts, "")
									end
								end
								
								-- Extract the text to replace
								text_to_replace = table.concat(vim.list_slice(lines, start_line, start_line + pattern_line_count - 1), "\n")
								from_text = text_to_replace
								
								-- Try direct string manipulation instead of gsub
								local match_position = new_content:find(text_to_replace, 1, true)
								if match_position then
									-- Create new content by explicit concatenation
									local before = new_content:sub(1, match_position - 1)
									local after = new_content:sub(match_position + #text_to_replace)
									new_content = before .. replacement.to .. after
								else
									-- If direct match failed, try gsub anyway
									local gsub_result = new_content:gsub(text_to_replace, replacement.to, 1)
									
									-- If gsub didn't change anything, try the simpler approach
									if gsub_result == new_content then
										-- Get the actual lines from original content
										local original_text = {}
										for i = 0, pattern_line_count - 1 do
											if start_line + i <= #lines then
												table.insert(original_text, lines[start_line + i])
											end
										end
										original_text = table.concat(original_text, "\n")
										from_text = original_text
										
										-- Try direct string manipulation again
										match_position = new_content:find(original_text, 1, true)
										if match_position then
											-- Create new content by explicit concatenation
											local before = new_content:sub(1, match_position - 1)
											local after = new_content:sub(match_position + #original_text)
											new_content = before .. replacement.to .. after
										else
											-- Last resort - use gsub on the original text
											new_content = new_content:gsub(original_text, replacement.to, 1)
										end
									else
										-- gsub worked, use its result
										new_content = gsub_result
									end
								end
							else
								table.insert(results, "Warning: String not found in " .. file_path .. " (even with whitespace normalization):\n" .. replacement.from)
								-- Continue with other replacements
							end
						else
							-- Exact match succeeded, try direct string manipulation
							local before = new_content:sub(1, exact_match - 1)
							local after = new_content:sub(exact_match + #replacement.from)
							new_content = before .. replacement.to .. after
						end
						
						-- If no changes were made, move to the next file
						if new_content == content then
							table.insert(results, "No changes made to " .. file_path)
							process_file(file_index + 1)
							return
						end
						
						-- Generate diff
						local diff_content = highlights.generate_diff(content, new_content)
						
						-- Show diff and ask for confirmation
						vim.schedule(function()
							-- Display diff in a temporary buffer
							local temp_bufnr = vim.api.nvim_create_buf(false, true)
							vim.api.nvim_buf_set_option(temp_bufnr, "buftype", "nofile")
							vim.api.nvim_buf_set_option(temp_bufnr, "bufhidden", "wipe")
							vim.api.nvim_buf_set_option(temp_bufnr, "filetype", "diff")
							
							-- Set the diff content
							vim.api.nvim_buf_set_lines(temp_bufnr, 0, -1, false, vim.split(diff_content, "\n"))
							
							-- Create a window for the diff
							local width = vim.api.nvim_get_option("columns")
							local height = vim.api.nvim_get_option("lines")
							local win_width = math.floor(width * 0.8)
							local win_height = math.floor(height * 0.8)
							local row = math.floor((height - win_height) / 2)
							local col = math.floor((width - win_width) / 2)
							
							local win_opts = {
								relative = "editor",
								width = win_width,
								height = win_height,
								row = row,
								col = col,
								style = "minimal",
								border = "rounded",
								title = "Confirm Changes to " .. file_path,
								title_pos = "center",
							}
							
							local win_id = vim.api.nvim_open_win(temp_bufnr, true, win_opts)
							
							-- Set window-specific options
							vim.api.nvim_win_set_option(win_id, "wrap", false)
							
							-- Create an inline colorized diff for the prompt
							local inline_diff = create_inline_diff(from_text, to_text, 8)
							
							-- Prompt for confirmation with inline diff
							local choice = vim.fn.confirm(
								"Apply these changes to " .. file_path .. "?\n\n" .. inline_diff,
								"&Yes\n&No", 
								2
							)
							
							vim.api.nvim_win_close(win_id, true)
							
							if choice == 1 then -- Yes
								-- Write the changes to the file
								local file = io.open(file_path, "w")
								if not file then
									table.insert(results, "Error: Could not write to " .. file_path)
								else
									file:write(new_content)
									file:close()
									table.insert(results, "✅ Changes applied to " .. file_path)
								end
							else
								table.insert(results, "❌ Changes rejected for " .. file_path)
							end
							
							-- Move to the next file
							process_file(file_index + 1)
						end)
					end
				end
				
				-- Start processing with the first file
				process_file(1)
			end)
		end,
	},
	
	replace_by_lines = {
		name = "replace_lines",
		description = "Replace specific line ranges in files with new content. Use this when exact text matching is failing. Specify start and end line numbers for each file.",
		input_schema = {
			type = "object",
			properties = {
				files = {
					type = "array",
					description = "Array of file objects that each contain line replacements to be made",
					items = {
						type = "object",
						properties = {
							path = {
								type = "string",
								description = "Absolute path to the file",
							},
							start_line = {
								type = "number",
								description = "The 1-based line number where replacement should start",
							},
							end_line = {
								type = "number",
								description = "The 1-based line number where replacement should end (inclusive)",
							},
							new_content = {
								type = "string",
								description = "The new content to replace the specified lines with",
							},
						},
						required = { "path", "start_line", "end_line", "new_content" },
					},
				},
			},
			required = { "files" },
		},
		handler = function(args, callback)
			-- Validate input
			if not args.files or #args.files == 0 then
				return callback("Error: No files specified for replacement")
			end
			
			vim.schedule(function()
				-- Process each file in sequence
				local results = {}
				local function process_file(file_index)
					if file_index > #args.files then
						-- All files processed, return results
						callback(table.concat(results, "\n\n"))
						return
					end
					
					local file_info = args.files[file_index]
					local file_path = file_info.path
					local start_line = file_info.start_line
					local end_line = file_info.end_line
					local new_content = file_info.new_content
					
					-- Validate line numbers
					if start_line < 1 or end_line < start_line then
						table.insert(results, "Error: Invalid line numbers for " .. file_path)
						process_file(file_index + 1)
						return
					end
					
					-- Read the file content
					local ok, file_content = pcall(vim.fn.readfile, file_path)
					if not ok then
						table.insert(results, "Error reading " .. file_path .. ": File not found or not readable")
						process_file(file_index + 1)
						return
					end
					
					-- Check line bounds
					if start_line > #file_content then
						table.insert(results, "Error: Start line " .. start_line .. " exceeds file length " .. #file_content)
						process_file(file_index + 1)
						return
					end
					
					end_line = math.min(end_line, #file_content)
					
					-- Extract the original content being replaced
					local original_lines = {}
					for i = start_line, end_line do
						table.insert(original_lines, file_content[i])
					end
					local original_content = table.concat(original_lines, "\n")
					
					-- Split new content into lines
					local new_lines = vim.split(new_content, "\n")
					
					-- Create the modified content
					local original_full_content = table.concat(file_content, "\n")
					local new_file_content = {}
					
					-- Copy lines before the replacement
					for i = 1, start_line - 1 do
						table.insert(new_file_content, file_content[i])
					end
					
					-- Add the new lines
					for _, line in ipairs(new_lines) do
						table.insert(new_file_content, line)
					end
					
					-- Copy lines after the replacement
					for i = end_line + 1, #file_content do
						table.insert(new_file_content, file_content[i])
					end
					
					local modified_content = table.concat(new_file_content, "\n")
					
					-- If no changes were made, move to the next file
					if modified_content == original_full_content then
						table.insert(results, "No changes made to " .. file_path)
						process_file(file_index + 1)
						return
					end
					
					-- Generate diff
					local diff_content = highlights.generate_diff(original_full_content, modified_content)
					
					-- Show diff and ask for confirmation
					vim.schedule(function()
						-- Display diff in a temporary buffer
						local temp_bufnr = vim.api.nvim_create_buf(false, true)
						vim.api.nvim_buf_set_option(temp_bufnr, "buftype", "nofile")
						vim.api.nvim_buf_set_option(temp_bufnr, "bufhidden", "wipe")
						vim.api.nvim_buf_set_option(temp_bufnr, "filetype", "diff")
						
						-- Set the diff content
						vim.api.nvim_buf_set_lines(temp_bufnr, 0, -1, false, vim.split(diff_content, "\n"))
						
						-- Create a window for the diff
						local width = vim.api.nvim_get_option("columns")
						local height = vim.api.nvim_get_option("lines")
						local win_width = math.floor(width * 0.8)
						local win_height = math.floor(height * 0.8)
						local row = math.floor((height - win_height) / 2)
						local col = math.floor((width - win_width) / 2)
						
						local win_opts = {
							relative = "editor",
							width = win_width,
							height = win_height,
							row = row,
							col = col,
							style = "minimal",
							border = "rounded",
							title = string.format("Confirm Changes to %s (lines %d-%d)", file_path, start_line, end_line),
							title_pos = "center",
						}
						
						local win_id = vim.api.nvim_open_win(temp_bufnr, true, win_opts)
						
						-- Set window-specific options
						vim.api.nvim_win_set_option(win_id, "wrap", false)
						
						-- Create an inline colorized diff for the prompt
						local inline_diff = create_inline_diff(original_content, new_content, 8)
						
						-- Prompt for confirmation with inline diff
						local choice = vim.fn.confirm(
							string.format("Apply these changes to %s (lines %d-%d)?\n\n%s", 
								file_path, start_line, end_line, inline_diff), 
							"&Yes\n&No", 
							2
						)
						
						vim.api.nvim_win_close(win_id, true)
						
						if choice == 1 then -- Yes
							-- Write the changes to the file
							local file = io.open(file_path, "w")
							if not file then
								table.insert(results, "Error: Could not write to " .. file_path)
							else
								file:write(modified_content)
								file:close()
								table.insert(results, string.format("✅ Changed lines %d-%d in %s", start_line, end_line, file_path))
							end
						else
							table.insert(results, "❌ Changes rejected for " .. file_path)
						end
						
						-- Move to the next file
						process_file(file_index + 1)
					end)
				end
				
				-- Start processing with the first file
				process_file(1)
			end)
		end,
	},
}

return tools