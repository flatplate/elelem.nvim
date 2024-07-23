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

M.llama_3_1_405B = {
    name = "llama-3.1-405b-reasoning",
    provider = providers.groq,
    supports_system_message = true
}

M.llama_3_1_70B = {
    name = "llama-3.1-70b-versatile",
    provider = providers.groq,
    supports_system_message = true
}

M.llama_3_1_8B = {
    name = "llama-3.1-8b-instant",
    provider = providers.groq,
    supports_system_message = true
}

M.llama_3_groq_70B = {
    name = "llama3-groq-70b-8192-tool-use-preview",
    provider = providers.groq,
    supports_system_message = true
}
M.llama_3_groq_8B = {
    name = "llama3-groq-8b-8192-tool-use-preview",
    provider = providers.groq,
    supports_system_message = true
}

M.meta_llama_3_70B = {
    name = "llama3-70b-8192",
    provider = providers.groq,
    supports_system_message = true
}

M.meta_llama_3_8B = {
    name = "llama3-8b-8192",
    provider = providers.groq,
    supports_system_message = true
}

M.mixtral_8x7B = {
    name = "mixtral-8x7b-32768",
    provider = providers.groq,
    supports_system_message = true
}

M.gemma_7B = {
    name = "gemma-7b-it",
    provider = providers.groq,
    supports_system_message = true
}

M.gemma_2_9B = {
    name = "gemma2-9b-it",
    provider = providers.groq,
    supports_system_message = true
}

return M
