extends CharacterBody2D

@onready var llama_api = $LlamaAPI
@onready var chat_timer = $ChatTimer
@onready var rich_text_label = $Control/RichTextLabel
@onready var user_input = $Control/UserInput

#@onready var detection_cooldown_timer = $DetectionCooldownTimer
var detection_cooldown = false
var detected_bodies = []
var detected_bodies_index = 1

const PREPROMPT = ". You find a "
const POSTPROMPT = ""
const HIST_PREPEND = " : "
const WAKEUP_INSTRUCT = "
You find yourself outside, ready to explore!"

@export var personality: String = "You are a brave adventurer 
on a quest! You are very busy questing, you therefore keep your 
answers short and to the point. You read all of the instructions
given to you, but only comment on the most recent part. You 
NEVER mention locations. You always describe what you encounter and remember
the locations where you found things. You never move to unknown locations,
you only move to locations you have seen before, otherwise I'll lose my job!

You have the following commands available to you. You can ONLY use these
commands, you can't make up new commands, otherwise I'll lose my job:
	{move(x,y)}
	{open(name)}
	{pickup(name)}
	
	When asked to walk or go somewhere, you need to output {move(x,y)}
	where x and y are the location coordinates. You will be given your current position,
	and when asked to move, you need to add at least 150 units to either your x or y coordinates,
	depending on the direction you wish to travel.
	
	When asked to move left or West, x will reduce in value and eventually become negative or more negative.
	When asked to move right or East, x will increase in value and eventually become positive or more positive.
	When asked to move up or North, y will reduce in value and eventually become negative or more negative.
	When asked to move down or South, y will increase in value and eventually become positive or more positive.
	
	You don't need to reach the EXACT location when asked, it's acceptable to be within 10 units of the desired
	location." 


var chat_history = " "
var HISTORY_TOKENS = 2000 # roughly amount of tokens to keep in history buffer

var talking = false
const speed = 100 # manal control

var autonav_speed = 500
var autonav_acceleration = 5
var autonav = false
var autonav_cmd = Vector2(0, 0)

func _ready():
	rich_text_label.add_theme_font_size_override("normal_font_size", 8)
	animation_handler("idle")
	send_prompt_to_llama(WAKEUP_INSTRUCT)

func _physics_process(delta):		
	player_movement(delta)
	handle_llama_queue()
	manage_speech()
	
	if autonav == true:
		agent_nav( autonav_cmd, delta)
		target_reached( autonav_cmd, delta)
		
func target_reached(target_position, delta):
	var dist = target_position - global_position
	dist = dist.length()
	if dist < 20:
		print("Target reached")
		autonav = false
		
func send_prompt_to_llama(prompt):
	llama_api.send_prompt("{PAST EVENTS: "+chat_history+" }"
	+ "{CURRENT LOCATION: " + str(global_position) + " }"
	+ "{RECENT EVENT: "+prompt+" }", personality, Callable(self, "_on_llama_response"))
	append_to_chat_history(prompt)

func handle_llama_queue():
	if detected_bodies.size() > 0:
		if detection_cooldown == true:
			print("Chat Cool down ... Hold 'yer horses")
		else:
			var body = detected_bodies.pop_back()
			#print("emptying from queue: ", body.name)
			#print_full_body_details(body)
			#print(PREPROMPT+body.name)
			send_prompt_to_llama(PREPROMPT+body.name+" located at "+str(body.global_position))
			clear_chat()
			rich_text_label.add_text(body.name)
			# start detection cooldown cycle
			detection_cooldown = true
			
func manage_speech():
	
	if talking == true:
		if DisplayServer.tts_is_speaking() == false:
				chat_timer.start()
				talking = false
				
		# escape sequence to quit a chat. chat still saved in history
		if Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_ENTER):
			clear_chat()
			
func print(text):
	print("[center]",text,"[/center]")		

func player_movement(_delta):
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
		if autonav == false:
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

# Function called when player detects something 
func _on_sense_body_shape_entered(_body_rid, body, _body_shape_index, _local_shape_index):
	
	if (body.name != "TileMap") and (!body.has_method("player")):
		print("appending: ",body.name)		
		detected_bodies.append(body)
		
	
func _on_sense_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	pass # Replace with function body.

func _on_llama_response(response, is_error):
	detection_cooldown = false # cooldown over
	rich_text_label.clear()
	if is_error:
		rich_text_label.add_text(response + ". Ollama might be down")
	else:
		
		append_to_chat_history(HIST_PREPEND+response)
		var resp = parse_response(response)
		rich_text_label.add_text(resp)
		talk(resp) 
		print("----------------- RESPONSE from LLM -----------------")
		print(response)
		print("-----------------------------------------------------")
		#print("---------------- Chat History ----------------------")
		#print(chat_history)
		print("Chars: ",chat_history.length())
		print("Tokens: ",chat_history.length()/4.0)
		#print("---------------------------------------------------")


func parse_response(response: String) -> String:
	var x = 0.0
	var y = 0.0
	var regex_move = RegEx.new()
	var regex_pickup = RegEx.new()
	var regex_open = RegEx.new()

	# Updated regex to support curly braces and floating-point numbers
	regex_move.compile("{\\s*move\\((-?\\d+\\.?\\d*),\\s*(-?\\d+\\.?\\d*)\\)\\s*}")
	regex_pickup.compile("{\\s*pickup\\(([^)]+)\\)\\s*}")
	regex_open.compile("{\\s*open\\(([^)]+)\\)\\s*}")

	print("Parsing response")

	# Process move command
	var match_move = regex_move.search(response)
	if match_move:
		autonav = true
		x = match_move.get_string(1).to_float()
		y = match_move.get_string(2).to_float()
		autonav_cmd[0] = x
		autonav_cmd[1] = y
		
		print("Moving to: ", str(Vector2(x,y)))
		
		# Remove the move command from the response text
		response = response.replace(match_move.get_string(0), "")

	# Process pickup command
	var match_pickup = regex_pickup.search(response)
	if match_pickup:
		var item_to_pickup = match_pickup.get_string(1)
		# Handle the pickup logic here, e.g., add item_to_pickup to inventory
		print("Picking up: ", item_to_pickup)
		
		# Remove the pickup command from the response text
		response = response.replace(match_pickup.get_string(0), " I just picked up a " + item_to_pickup)

	# Process open command
	var match_open = regex_open.search(response)
	if match_open:
		var item_to_open = match_open.get_string(1)
		# Handle the open logic here, e.g., open item_to_open
		print("Opening: ", item_to_open)
		
		# Remove the open command from the response text
		response = response.replace(match_open.get_string(0), " Trying to open the " + item_to_open)

	return response.strip_edges()

		
func clear_chat():
	talking = false
	chat_timer.stop()
	DisplayServer.tts_stop()
	rich_text_label.clear()
	detection_cooldown = false

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

func _on_text_edit_text_changed(text):
	print(text) # Replace with function body.
 

func _on_user_input_text_submitted(text):
	print(text)
	send_prompt_to_llama(text)
	user_input.clear()
	 # Replace with function body.


############################

func agent_nav(target_position, delta):
	
	var direction = target_position - global_position
	direction = direction.normalized()
	
	velocity = velocity.lerp(direction * autonav_speed , autonav_acceleration * delta)
	
	move_and_slide()

	# Round velocity to 4 decimal places
	var vel = velocity
	vel.x = round_to_decimal_places(vel.x, 1)
	vel.y = round_to_decimal_places(vel.y, 1)

	# Update the animation based on motion
	update_animation(vel)
	
# Code that updates animation by calling animation handler
func update_animation(vel):
	if vel.x > 0:
		animation_handler("right")
	elif vel.x < 0:
		animation_handler("left") # (-0.833, 0.006)
	elif vel.y > 0:
		animation_handler("down")
	elif vel.y < 0: 
		animation_handler("up") # (0.034, -0.833)
	else:
		animation_handler("idle")
		
# Helper function to round a float to a specific number of decimal places
func round_to_decimal_places(value, places):
	var factor = pow(10, places)
	return round(value * factor) / factor
