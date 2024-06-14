extends Node

# Signal for when speech is generated
signal ElevenLabs_generated_speech

# TTS provider selection (0: ESpeak, 1: Eleven Labs)
@export_enum("ESpeak", "Eleven Labs") var tts_provider: String

# Whether to use audio stream endpoint for Eleven Labs
@export var use_stream_mode: bool = false

var eleven_labs_voice_id: String = ""
var eleven_labs_api_key: String = ""

# The endpoint will actually include the voice id below
var endpoint: String = "https://api.elevenlabs.io/v1/text-to-speech/"

# The headers for the request required by Eleven Labs
var headers

# Audiostream player used to play speech
var eleven_labs_speech_player: AudioStreamPlayer

# Audiostream used for speech object produced by API
var eleven_labs_stream: AudioStreamMP3

# HTTP Request node used to query Eleven Labs API
var http_request: HTTPRequest

var tts_queue = []
var tts_busy = false

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_request_completed"))

	eleven_labs_speech_player = AudioStreamPlayer.new()
	add_child(eleven_labs_speech_player)
	
	var config = ConfigFile.new()
	if config.load("res://config.cfg") == OK:
		eleven_labs_voice_id = config.get_value("secrets", "ELEVEN_LABS_VOICE_ID", "")
		eleven_labs_api_key = config.get_value("secrets", "ELEVEN_LABS_API_KEY", "")

	if eleven_labs_voice_id == "" or eleven_labs_api_key == "":
		print("[TTS] ElevenLabs configuration is missing or incomplete.")
	else:
		print("[TTS] ElevenLabs TTS Initialized")
		update_headers_and_endpoint()

func update_headers_and_endpoint():
	# Endpoint and headers change depending on if using stream mode
	if use_stream_mode:
		endpoint = "https://api.elevenlabs.io/v1/text-to-speech/" + eleven_labs_voice_id + "/stream"
		headers = ["accept: */*", "xi-api-key: " + eleven_labs_api_key, "Content-Type: application/json"]
	else:
		endpoint = "https://api.elevenlabs.io/v1/text-to-speech/" + eleven_labs_voice_id
		headers = ["accept: audio/mpeg", "xi-api-key: " + eleven_labs_api_key, "Content-Type: application/json"]

# Call TTS API for text to speech
func talk(text: String):
	if tts_busy:
		tts_queue.append(text)
		return

	tts_busy = true
	
	if tts_provider == "Eleven Labs":  # Eleven Labs
		var data = {
			"text": text,
			"voice_settings": {"stability": 0, "similarity_boost": 0}
		}
		var json_data = JSON.stringify(data)
		# Now call Eleven Labs
		var error = http_request.request(endpoint, headers, HTTPClient.METHOD_POST, json_data)
		
		if error != OK:
			push_error("Something Went Wrong!")
			print(error)
			tts_busy = false
			use_espeak(text)  # Fallback to ESpeak TTS
	else:  # ESpeak
		use_espeak(text)
		tts_busy = false  # Reset the tts_busy flag after using ESpeak

# Called when response received from Eleven Labs
func _on_request_completed(result, response_code, headers, body):
	if response_code != 200:
		print("There was an error, response code: " + str(response_code))
		print(result)
		print(headers)
		print(body)
		# Fallback to ESpeak TTS
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		if parse_result == OK:
			var response = json.get_data()
			if response.has("detail") and typeof(response["detail"]) == TYPE_DICTIONARY and response["detail"].has("message"):
				use_espeak(response["detail"]["message"])
			else:
				use_espeak("Error processing the request.")
		else:
			use_espeak("Error processing the request.")
	else:
		var audio_stream = AudioStreamMP3.new()
		audio_stream.data = body
		eleven_labs_speech_player.stream = audio_stream
		eleven_labs_speech_player.play()
	
	# Reset tts_busy flag
	tts_busy = false
	
	# Let other nodes know that AI generated dialogue is ready from GPT
	emit_signal("ElevenLabs_generated_speech")

# Fallback to ESpeak TTS
func use_espeak(text: String):
	var voices = DisplayServer.tts_get_voices_for_language("en")
	if voices.size() > 0:
		var voice_id = voices[0]
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(text, voice_id)
	# Ensure tts_busy is reset after using ESpeak
	tts_busy = false
	
# Function to manage the speech queue
func manage_speech(chat_timer: Timer):
	if not eleven_labs_speech_player.is_playing() and tts_queue.size() > 0:
		talk(tts_queue.pop_front())

# Set new API key
func set_api_key(new_api_key: String):
	eleven_labs_api_key = new_api_key
	update_headers_and_endpoint()

# Set new voice id
func set_voice_id(new_voice_id: String):
	eleven_labs_voice_id = new_voice_id
	update_headers_and_endpoint()
