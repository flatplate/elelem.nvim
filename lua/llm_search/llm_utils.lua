local function query_llm(messages, callback, model)
  model.provider.request(model, messages, callback)
end

local function stream_llm(messages, callback, model)
  model.provider.stream(model, messages, callback)
end

local M = {
  query_llm = query_llm,
  stream_llm = stream_llm
}

return M
