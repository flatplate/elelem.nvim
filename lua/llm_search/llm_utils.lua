local io_utils = require("llm_search.io_utils")

local function get_messages(system_message, user_message)
  return {
    { role = "system", content = system_message },
    { role = "user",   content = user_message }
  }
end

local function query_llm(context, query, custom_prompt, callback, debug, model)
  local system_message =
      "You are the best code search assistant ever. You look at the files and example lines given to you and answer user's questions as well as possible. After each line of your answer, give the *full* file name that is the reference. Use the context to give the user good explanations. " ..
      (custom_prompt or "")

  local messages = get_messages(system_message, "CONTEXT\n######\n" .. context .. "\n#####\nQuery\n#####\n " .. query)

  if debug then
    local debug_content = "System Message:\n" .. system_message .. "\n\nContext and Query:\n" .. messages[2].content
    io_utils.print_to_split(debug_content)
  end
  model.provider.request(model, messages, callback)
end

local function stream_llm(context, query, custom_prompt, callback, model)
  local system_message = "You are the best programmer ever. " .. (custom_prompt or "")
  local messages = get_messages(system_message, "CONTEXT\n######\n" .. context .. "\n#####\nQuery\n#####\n " .. query)

  model.provider.stream(model, messages, callback)
end

local M = {
  query_llm = query_llm,
  stream_llm = stream_llm
}

return M

