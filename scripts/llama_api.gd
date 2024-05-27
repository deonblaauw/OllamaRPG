extends Node

@export var local_url: String = "http://localhost:11434/v1/chat/completions"
@export var openai_url: String = "https://api.openai.com/v1/chat/completions"
@export var local_headers = ["Content-Type: application/json"]

@export_enum(
	"command-r",
	"llama2", 
	"llama3", 
"OpenAI GPT-4o",
"OpenAI GPT-4", 
"OpenAI GPT-4-turbo", 
"OpenAI GPT-3.5-turbo-0125") var llm_type: String

var request: HTTPRequest
var callback: Callable
var message_queue = []
var is_busy = false

var OPENAI_API = ""

func _ready():
	var config = ConfigFile.new()
	if config.load("res://config.cfg") == OK:
		OPENAI_API = config.get_value("secrets", "OPENAI_API")

	print("[API] LLM API Initialized")
	request = HTTPRequest.new()
	add_child(request)
	request.connect("request_completed", Callable(self, "_on_request_completed"))

func send_prompt(user_prompt: String, system_prompt: String, loc_callback: Callable):
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	message_queue.append({"messages": messages, "callback": loc_callback})
	print("[API] Message added to queue: ", user_prompt)
	process_queue()

func process_queue():
	if is_busy or message_queue.size() == 0:
		return
	
	is_busy = true
	var current_message = message_queue.pop_front()
	self.callback = current_message["callback"]
	var messages = current_message["messages"]

	# Extract and print the user_prompt
	var user_prompt = ""
	for message in messages:
		if message["role"] == "user":
			user_prompt = message["content"]
			break

	print("[API] **************** Sending to " + llm_type + " ******************")
	print("[API] User Prompt: ", user_prompt)
	print("[API] ***************************************************************")

	var body = JSON.stringify({"messages": messages, "model": get_model()})
	var error = -1

	if llm_type == "llama2" or llm_type == "llama3" or llm_type == "command-r":
		error = request.request(local_url, local_headers, HTTPClient.METHOD_POST, body)
	else:
		var openai_headers = ["Content-Type: application/json", "Authorization: Bearer " + OPENAI_API]
		error = request.request(openai_url, openai_headers, HTTPClient.METHOD_POST, body)

	if error != OK:
		callback.call("Error: Request failed", true)
		is_busy = false
		process_queue()


func _on_request_completed(_result, response_code, _headers, body):
	is_busy = false
	if response_code != 200:
		print("[API] LLM API ERROR")
		print("[API] Response Code: ", response_code)
		print("[API] Response Body: ", body.get_string_from_utf8())
		callback.call("Error: HTTP " + str(response_code), true)
		process_queue()
		return

	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		callback.call("Error: Failed to parse response", true)
		process_queue()
		return

	var result = json.data
	if not result.has("choices") or result["choices"].size() == 0:
		callback.call("Error: Invalid response format", true)
		process_queue()
		return

	var message = result["choices"][0]["message"]["content"]
	callback.call(message, false)
	process_queue()

func get_model() -> String:
	match llm_type:
		"command-r":
			return "command-r"
		"llama2":
			return "llama2"
		"llama3":
			return "llama3"
		"OpenAI GPT-4o":
			return "gpt-4o"
		"OpenAI GPT-4":
			return "gpt-4"
		"OpenAI GPT-4-turbo":
			return "gpt-4-turbo"
		"OpenAI GPT-3.5-turbo-0125":
			return "gpt-3.5-turbo-0125"
		_:
			return "gpt-4"
