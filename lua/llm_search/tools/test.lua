return {
	weather = {
		name = "get_weather",
		description = "Get the current weather for a location",
		input_schema = { -- Changed from parameters to input_schema
			type = "object",
			properties = {
				location = {
					type = "string",
					description = "The city name to get weather for",
				},
			},
			required = { "location" },
		},
		handler = function(args, callback)
			-- Return fixed response
			callback([[{
                "temperature": 42,
                "unit": "C",
                "description": "Always sunny at 42°C"
            }]])
		end,
	},
}
