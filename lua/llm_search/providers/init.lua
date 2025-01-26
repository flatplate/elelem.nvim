local anthropic = require("llm_search.providers.anthropic")
local openai = require("llm_search.providers.openai")
local groq = require("llm_search.providers.groq")
local fireworks = require("llm_search.providers.fireworks")

local set_config = function(config)
	anthropic.set_config(config)
	openai.set_config(config)
	groq.set_config(config)
	fireworks.set_config(config)
end

return {
	set_config = set_config,
	anthropic = anthropic,
	openai = openai,
	groq = groq,
	fireworks = fireworks,
}
