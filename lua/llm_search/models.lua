local M = {}
local providers = require("llm_search.providers")

M.deepseek = {
    name = "accounts/fireworks/models/deepseek-coder-v2-lite-instruct",
    supports_system_message = true,
    provider = providers.fireworks
}

M.deepseek_base = {
    name = "accounts/fireworks/models/deepseek-coder-v2-instruct",
    supports_system_message = true,
    provider = providers.fireworks
}

M.gemma = {
    name = "accounts/fireworks/models/gemma2-9b-it",
    provider = providers.fireworks,
    supports_system_message = true
}

M.claude_3_opus = {
    name = "claude-3-opus-20240229",
    provider = providers.anthropic,
    supports_system_message = true
}

M.claude_3_5_sonnet = {
    name = "claude-3-5-sonnet-20240620",
    provider = providers.anthropic,
    supports_system_message = true
}

M.claude_2 = {
    name = "claude-2.1",
    provider = providers.anthropic,
    supports_system_message = true
}

M.gpt4omini = {
    name = "gpt-4o-mini",
    provider = providers.openai,
    supports_system_message = true
}

M.gpt4o = {
    name = "gpt-4o",
    provider = providers.openai,
    supports_system_message = true
}

return M
