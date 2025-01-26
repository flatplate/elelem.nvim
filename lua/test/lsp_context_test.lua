local test_utils = require("test.test_utils")
test_utils.init_vim_mock()
local lsp_context = require("llm_search.context_suppliers.lsp")

local function test_find_position_beginning()
	local file_content = "hello world"
	local marked = "§hello§"
	local pos = lsp_context.find_position_from_snippet(file_content, marked)

	test_utils.assert_not_nil(pos, "Position should be found")
	test_utils.assert_equals(0, pos.line, "Line number should be 0")
	test_utils.assert_equals(0, pos.character, "Character position should be 0")
end

local function test_find_position_basic()
	local file_content = "local function hello()\n  print('hi')\nend"
	local marked = "local function §hello§()"
	local pos = lsp_context.find_position_from_snippet(file_content, marked)

	test_utils.assert_not_nil(pos, "Position should be found")
	test_utils.assert_equals(0, pos.line, "Line number should be 0")
	test_utils.assert_equals(15, pos.character, "Character position should be 13")
end

local function test_find_position_complex_symbol()
	local file_content = "local my_Function123 = require('module')"
	local marked = "local §my_Function123§ = require"
	local pos = lsp_context.find_position_from_snippet(file_content, marked)

	test_utils.assert_not_nil(pos, "Position should be found")
	test_utils.assert_equals(0, pos.line, "Line number should be 0")
	test_utils.assert_equals(6, pos.character, "Character position should be 6")
end

local function test_snippet_not_found()
	local file_content = "some content"
	local marked = "different §content§"
	local pos = lsp_context.find_position_from_snippet(file_content, marked)

	test_utils.assert_nil(pos, "Should return nil when snippet not found")
end

local function test_multiline_snippet()
	local file_content = "if true then\n  local x = test_func()\n  print(x)\nend"
	local marked = "local x = §test_func§()"
	local pos = lsp_context.find_position_from_snippet(file_content, marked)

	test_utils.assert_not_nil(pos, "Position should be found")
	test_utils.assert_equals(1, pos.line, "Line number should be 1")
	test_utils.assert_equals(12, pos.character, "Character position should be 11")
end

test_find_position_beginning()
print("Beginning position finding test passed!")
test_find_position_basic()
print("Basic position finding test passed!")
test_find_position_complex_symbol()
print("Complex symbol position finding test passed!")
test_snippet_not_found()
print("Snippet not found test passed!")
test_multiline_snippet()
print("Multiline position finding test passed!")
print("All position finding tests passed!")
