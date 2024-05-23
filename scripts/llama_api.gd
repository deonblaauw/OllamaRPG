extends Node

@export var url: String = "http://localhost:11434/v1/chat/completions"
@export var headers = ["Content-Type: application/json"]
@export var model: String = "llama2"
@export var system_prompt: String = "You are dumb dumb because you have not been initialized. You cannot answers questions and just say: duh, please init me."

var request: HTTPRequest
var callback: Callable

func _ready():
	print("Llamas running...")
	request = HTTPRequest.new()
	add_child(request)
	request.connect("request_completed", Callable(self, "_on_request_completed"))

func send_prompt(user_prompt: String, system_prompt: String, callback: Callable):
	self.callback = callback
	
	var messages = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	
	var body = JSON.new().stringify({"messages": messages, "model": model})
	var error = request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		callback.call("Error: Request failed", true)

func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		print("LlamaAPI ERROR. Ollama might be down...")
		callback.call("Error: HTTP " + str(response_code), true)
		return
	
	var response = JSON.new()
	response = response.parse_string(body.get_string_from_utf8())
	#print(response["choices"][0]["message"]["content"])

	var message = response["choices"][0]["message"]["content"]
	callback.call(message, false)
