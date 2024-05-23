extends CharacterBody2D

@onready var llama_api = $LlamaAPI
@onready var chat_timer = $ChatTimer
@onready var rich_text_label = $Control/RichTextLabel

const PREPROMPT = " .You see and describe a "
const HIST_PREPEND = " : "

@export var personality: String = "You are a brave adventurer 
on a quest! You are very busy questing, you therefore keep your 
answers short and to the point. You read all of the instructions
given to you, but only comment on the most recent part."


var chat_history = " "
var HISTORY_TOKENS = 2000 # roughly amount of tokens to keep in history buffer

var talking = false
const speed = 100

func _ready():
	rich_text_label.add_theme_font_size_override("normal_font_size", 8)
	animation_handler("idle")

func _physics_process(delta):
	#print(DisplayServer.tts_is_speaking())
	player_movement(delta)
	
	if talking == true:
		if DisplayServer.tts_is_speaking() == false:
				chat_timer.start()
				talking = false
		
	
func send_prompt_to_llama(prompt):
	llama_api.send_prompt(chat_history+prompt, personality, Callable(self, "_on_llama_response"))
	append_to_chat_history(prompt)


func player_movement(delta):
	delta = delta
	if Input.is_action_pressed("ui_right"):
		velocity.x = speed
		velocity.y = 0
		animation_handler("right")
		if Input.is_action_pressed("ui_up"):
			velocity.y = -speed
		elif Input.is_action_pressed("ui_down"):
			velocity.y = speed
	elif Input.is_action_pressed("ui_left"):
		velocity.x = -speed
		velocity.y = 0
		animation_handler("left")
		if Input.is_action_pressed("ui_up"):
			velocity.y = -speed
		elif Input.is_action_pressed("ui_down"):
			velocity.y = speed
	elif Input.is_action_pressed("ui_down"):
		velocity.x = 0
		velocity.y = speed
		animation_handler("down")
	elif Input.is_action_pressed("ui_up"):
		velocity.x = 0
		velocity.y = -speed
		animation_handler("up")
	else:
		velocity.x = 0
		velocity.y = 0
		animation_handler("idle")
		
	move_and_slide() #< Godot buil-in
		
# Code that handles our animation
func animation_handler(direction):
	
	if direction == "right":
		$AnimatedSprite2D.flip_h = false
		$AnimatedSprite2D.play("side_walk_right")
	elif direction == "left":
		$AnimatedSprite2D.flip_h = true
		$AnimatedSprite2D.play("side_walk_right")
	elif direction == "up":
		$AnimatedSprite2D.play("back_walk")
	elif direction == "down":
		$AnimatedSprite2D.play("front_walk")
	elif direction == "idle":
		$AnimatedSprite2D.play("side_idle_right")
	else:
		$AnimatedSprite2D.play("side_idle_right")
	
func talk(msg):
	var voices = DisplayServer.tts_get_voices_for_language("en")
	var voice_id = voices[0]
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(msg, voice_id)
	talking = true

func _on_sense_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	#print("[Player] Body entered") # Replace with function body.
	body_rid = body_rid
	body_shape_index = body_shape_index
	local_shape_index = local_shape_index
	if (body.name != "TileMap") and (!body.has_method("player")):
		#print_full_body_details(body)
		print(PREPROMPT+body.name)
		send_prompt_to_llama(PREPROMPT+body.name)
		talking = false
		chat_timer.stop()
		DisplayServer.tts_stop()
		rich_text_label.clear()
		rich_text_label.add_text(body.name)
	

func _on_llama_response(response, is_error):
	
	rich_text_label.clear()
	if is_error:
		rich_text_label.add_text(response + ". Ollama might be down")
	else:
		rich_text_label.add_text(response)
		append_to_chat_history(HIST_PREPEND+response)
		talk(response) 
		print("---------------- Chat History ----------------------")
		print(chat_history)
		print("Chars: ",chat_history.length())
		print("Tokens: ",chat_history.length()/4)
		print("---------------------------------------------------")

func append_to_chat_history(text):
	# Append new text to the chat history
	chat_history += text
	
	# Calculate the maximum character limit based on HISTORY_TOKENS
	var max_chars = HISTORY_TOKENS * 4
	
	# Check if the length of chat_history exceeds the maximum characters
	if chat_history.length() > max_chars:
		# If it does, slice the chat_history to only keep the most recent max_chars characters
		chat_history = chat_history.substr(chat_history.length() - max_chars, max_chars)


func print_body_details(body):
	print("Body Name: ", body.name)
	print("Body Type: ", typeof(body))
	
func print_full_body_details(body):
	# Print basic metadata
	print("Body Name: ", body.name)
	print("Body Type: ", typeof(body))
	if body.has_method("get_position"):
		print("Body Position: ", body.get_position())
	else:
		print("Body Position: Not available")
	
	# If the body has a velocity (like CharacterBody2D or RigidBody2D)
	if body.has_method("get_velocity"):
		print("Body Velocity: ", body.get_velocity())
	else:
		print("Body Velocity: Not available")
	
	# Print any custom properties (if you have any)
	if body.has_method("get_custom_metadata"):
		print("Custom Metadata: ", body.get_custom_metadata())

	# Print all properties of the body (optional, can be verbose)
	var body_properties = body.get_property_list()
	for property in body_properties:
		var property_name = property.name
		var property_value = body.get(property_name)
		print("%s: %s" % [property_name, str(property_value)])


func _on_chat_timer_timeout():
	rich_text_label.clear()
	print("clear chat") # Replace with function body.

func player():
	pass
