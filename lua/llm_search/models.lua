local M = {}
local providers = require("llm_search.providers")

-- Fireworks models

M.deepseek = {
	name = "accounts/fireworks/models/deepseek-coder-v2-lite-instruct",
	supports_system_message = true,
	provider = providers.fireworks,
}

M.deepseek_base = {
	name = "accounts/fireworks/models/deepseek-coder-v2-instruct",
	supports_system_message = true,
	provider = providers.fireworks,
}

M.gemma = {
	name = "accounts/fireworks/models/gemma2-9b-it",
	provider = providers.fireworks,
	supports_system_message = true,
}

M.llama_3_1_405B_fireworks = {
	name = "accounts/fireworks/models/llama-v3p1-405b-instruct",
	provider = providers.fireworks,
	supports_system_message = true,
}

M.llama_3_1_70B_fireworks = {
	name = "accounts/fireworks/models/llama-v3p1-70b-instruct",
	provider = providers.fireworks,
	supports_system_message = true,
}

M.llama_3_1_8B_fireworks = {
	name = "accounts/fireworks/models/llama-v3p1-8b-instruct",
	provider = providers.fireworks,
	supports_system_message = true,
}

M.qwen = {
	name = "accounts/fireworks/models/qwen2p5-72b-instruct",
	provider = providers.fireworks,
	supports_system_message = true,
}

M.deepseek_3 = {
	name = "accounts/fireworks/models/deepseek-v3",
	provider = providers.fireworks,
	supports_system_message = true,
}

M.deepseek_r1 = {
	name = "accounts/fireworks/models/deepseek-r1",
	provider = providers.fireworks,
	supports_system_message = true,
}

-- Anthropic models

M.claude_3_opus = {
	name = "claude-3-opus-20240229",
	provider = providers.anthropic,
	supports_system_message = true,
}

M.claude_3_5_sonnet = {
	name = "claude-3-5-sonnet-20241022",
	provider = providers.anthropic,
	supports_system_message = true,
	supports_tool_use = true,
}

M.claude_3_7_sonnet = {
	name = "claude-3-7-sonnet-latest",
	provider = providers.anthropic,
	supports_system_message = true,
	supports_tool_use = true,
}

M.claude_3_haiku = {
	name = "claude-3-haiku-20240307",
	provider = providers.anthropic,
	supports_system_message = true,
}

M.claude_3_5_haiku = {
	name = "claude-3-5-haiku-20241022",
	provider = providers.anthropic,
	supports_system_message = true,
	supports_tool_use = true,
}

M.claude_2 = {
	name = "claude-2.1",
	provider = providers.anthropic,
	supports_system_message = true,
}

-- OpenAI models

M.gpt4omini = {
	name = "gpt-4o-mini",
	provider = providers.openai,
	supports_system_message = true,
}

M.gpt4o = {
	name = "gpt-4o",
	provider = providers.openai,
	supports_system_message = true,
}

-- Groq models

M.llama_3_1_405B = {
	name = "llama-3.1-405b-reasoning",
	provider = providers.groq,
	supports_system_message = true,
}

M.llama_3_1_70B = {
	name = "llama-3.1-70b-versatile",
	provider = providers.groq,
	supports_system_message = true,
}

M.llama_3_1_8B = {
	name = "llama-3.1-8b-instant",
	provider = providers.groq,
	supports_system_message = true,
}

M.llama_3_groq_70B = {
	name = "llama3-groq-70b-8192-tool-use-preview",
	provider = providers.groq,
	supports_system_message = true,
}
M.llama_3_groq_8B = {
	name = "llama3-groq-8b-8192-tool-use-preview",
	provider = providers.groq,
	supports_system_message = true,
}

M.meta_llama_3_70B = {
	name = "llama3-70b-8192",
	provider = providers.groq,
	supports_system_message = true,
}

M.meta_llama_3_8B = {
	name = "llama3-8b-8192",
	provider = providers.groq,
	supports_system_message = true,
}

M.mixtral_8x7B = {
	name = "mixtral-8x7b-32768",
	provider = providers.groq,
	supports_system_message = true,
}

M.gemma_7B = {
	name = "gemma-7b-it",
	provider = providers.groq,
	supports_system_message = true,
}

M.gemma_2_9B = {
	name = "gemma2-9b-it",
	provider = providers.groq,
	supports_system_message = true,
}

-- Models by provider

M.by_provider = {
	fireworks = {
		M.deepseek,
		M.deepseek_base,
		M.gemma,
		llama_3_1_405B = M.llama_3_1_405B_fireworks,
		llama_3_1_70B = M.llama_3_1_70B_fireworks,
		llama_3_1_8B = M.llama_3_1_8B_fireworks,
	},
	anthropic = {
		M.claude_3_opus,
		M.claude_3_5_sonnet,
		M.claude_2,
	},
	openai = {
		M.gpt4omini,
		M.gpt4o,
	},
	groq = {
		M.llama_3_1_405B,
		M.llama_3_1_70B,
		M.llama_3_1_8B,
		M.llama_3_groq_70B,
		M.llama_3_groq_8B,
		M.meta_llama_3_70B,
		M.meta_llama_3_8B,
		M.mixtral_8x7B,
		M.gemma_7B,
		M.gemma_2_9B,
	},
}

return M
