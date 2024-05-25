extends Node

@export var local_url: String = "http://localhost:11434/v1/chat/completions"
@export var openai_url: String = "https://api.openai.com/v1/chat/completions"
@export var local_headers = ["Content-Type: application/json"]

@export_enum("llama2", "llama3", "OpenAI GPT-4", "OpenAI GPT-4-turbo", "OpenAI GPT-3.5-turbo-0125") var llm_type: String

var request: HTTPRequest
var callback: Callable

var OPENAI_API = ""

func _ready():
	var config = ConfigFile.new()
	if config.load("res://config.cfg") == OK:
		OPENAI_API = config.get_value("secrets", "OPENAI_API")

	print("LLM API Initialized")
	request = HTTPRequest.new()
	add_child(request)
	request.connect("request_completed", Callable(self, "_on_request_completed"))

func send_prompt(user_prompt: String, system_prompt: String, loc_callback: Callable):
	self.callback = loc_callback
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	print("**********************************")
	print("Sending to ", llm_type)
	print(messages)
	print("**********************************")
	
	var body = JSON.stringify({"messages": messages, "model": get_model()})
	var error = -1
	
	if llm_type == "llama2" or llm_type == "llama3":
		error = request.request(local_url, local_headers, HTTPClient.METHOD_POST, body)
	else:
		var openai_headers = ["Content-Type: application/json", "Authorization: Bearer " + OPENAI_API]
		error = request.request(openai_url, openai_headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		callback.call("Error: Request failed", true)

func _on_request_completed(_result, response_code, _headers, body):
	if response_code != 200:
		print("LLM API ERROR")
		print("Response Code: ", response_code)
		print("Response Body: ", body.get_string_from_utf8())
		callback.call("Error: HTTP " + str(response_code), true)
		return
	
	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		callback.call("Error: Failed to parse response", true)
		return
	
	var result = json.data
	if not result.has("choices") or result["choices"].size() == 0:
		callback.call("Error: Invalid response format", true)
		return
	
	var message = result["choices"][0]["message"]["content"]
	callback.call(message, false)

func get_model() -> String:
	match llm_type:
		"llama2":
			return "llama2"
		"llama3":
			return "llama3"
		"OpenAI GPT-4":
			return "gpt-4"
		"OpenAI GPT-4-turbo":
			return "gpt-4-turbo"
		"OpenAI GPT-3.5-turbo-0125":
			return "gpt-3.5-turbo-0125"
		_:
			return "gpt-4"
