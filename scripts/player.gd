extends CharacterBody2D

signal chest_command

@onready var llama_api = $LlamaAPI
@onready var chat_timer = $ChatTimer
@onready var rich_text_label = $Control/RichTextLabel
@onready var user_input = $Control/UserInput
@onready var position_response_timer = $PositionResponseTimer
@onready var command_display = $"Command Display/CommandDisplay"
@onready var cmd_disp_timer = $"Command Display/cmdDispTimer" # Add HTTPRequest node to your scene
#@onready var tts = preload("res://scripts/tts.gd").new()  # Load the TTS script as a library
@onready var tts = $tts

const OBJECT_PREPROMPT = ". You find a "
const HIST_PREPEND = " : "

const POS_UPDATE_MSG = """
Take a deep breath. Think step-by-step. Explain what you are doing and why you are doing it. 
After explaining your thought process, you report your {current_location"""
const WAKEUP_INSTRUCT = "You wake up"

@export var personality_file_path: String = "res://scripts//personality-1.txt"
var personality: String

var chat_history = " "
var HISTORY_TOKENS = 2000 # roughly amount of tokens to keep in history buffer

var talking = false
var tts_queue = []
var tts_busy = false

const speed = 100 # manal control

var autonav_speed = 500
var autonav_acceleration = 5
var autonav = false
var autonav_cmd = Vector2(0, 0)

var llm_queue = []
var llm_busy = false

var _body = null

func _ready():
	add_child(tts)
	#tts.use_eleven_labs = true  # Set this to true or false as needed
	rich_text_label.add_theme_font_size_override("normal_font_size", 8)
	animation_handler("idle")
	send_prompt_to_llama(WAKEUP_INSTRUCT)
	position_response_timer.start()
	personality = load_personality_from_file(personality_file_path)
	print("[Player] Personality loaded: ==> ", personality)

func _physics_process(delta):		
	player_movement(delta)
	handle_llama_queue()
	tts.manage_speech(chat_timer)
	
	if autonav == true:
		agent_nav(autonav_cmd, delta)
		target_reached(autonav_cmd, delta)

func load_personality_from_file(file_path: String) -> String:
	print("path: ",file_path)
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	else:
		print("Error: File not found at ", file_path)
		return ""

						
func target_reached(target_position, delta):
	var dist = target_position - global_position
	dist = dist.length()
	if dist < 20:
		print("[Player] Target reached")
		autonav = false
		
func send_prompt_to_llama(prompt):
	var messages = [
		{"role": "system", "content": personality},
		{"role": "user", "content": prompt}
	]
	llm_queue.append(messages)
	handle_llama_queue()

func handle_llama_queue():
	print("llm busy: ",llm_busy)
	print("llm queue size: ", llm_queue.size())
	print("tts busy: ",tts.tts_busy)
	if llm_busy or llm_queue.size() == 0 or tts.tts_busy:
		return
	
	llm_busy = true
	var x = round_to_decimal_places(global_position.x, 0)
	var y = round_to_decimal_places(global_position.y, 0)
	
	var messages = llm_queue.pop_front()
	llama_api.send_prompt(
		"{PAST EVENTS: "+chat_history+" }"
		+ "{CURRENT LOCATION: " +"("+str(x)+","+str(y)+ " }"
		+ "{RECENT EVENT: "+messages[1]["content"]+" }", 
		personality, 
		Callable(self, "_on_llama_response")
	)
	print("[Player] handle_llama_queue()")
	append_to_chat_history(messages[1]["content"])

func player_movement(_delta):
	if Input.is_action_pressed("ui_right"):
		velocity.x = speed
		velocity.y = 0
		animation_handler("right")
		autonav = false
		if Input.is_action_pressed("ui_up"):
			velocity.y = -speed
		elif Input.is_action_pressed("ui_down"):
			velocity.y = speed
	elif Input.is_action_pressed("ui_left"):
		velocity.x = -speed
		velocity.y = 0
		animation_handler("left")
		autonav = false
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

func _on_sense_body_shape_entered(_body_rid, body, _body_shape_index, _local_shape_index):
	if (body.name != "TileMap") and (!body.has_method("player")):
		print("[Player] found: ",body.name)		
		#detected_bodies.append(body)
		var x = round_to_decimal_places(body.global_position.x, 0)
		var y = round_to_decimal_places(body.global_position.y, 0)
		send_prompt_to_llama(OBJECT_PREPROMPT+body.name+" located at "+"("+str(x)+","+str(y)+")")
		_body = body
		
	
	if _body != null:
		print(_body.name)
		
		
func _on_sense_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	pass # Replace with function body.

func _on_llama_response(response, is_error):
	llm_busy = false
	rich_text_label.clear()
	if is_error:
		rich_text_label.add_text(response + ". Ollama might be down")
	else:
		append_to_chat_history(HIST_PREPEND+response)
		var resp = parse_response(response)
		rich_text_label.add_text(resp)
		tts.talk(resp) 
		print("[Player] ----------------- RESPONSE from LLM -----------------")
		print(response)
		print("[Player] ----------------- current chat history stats --------")
		print("[Player] Chars: ",chat_history.length())
		print("[Player] Tokens: ",chat_history.length()/4.0)
		print("[Player] -----------------------------------------------------")
	handle_llama_queue()

func parse_response(response: String) -> String:
	var x = 0.0
	var y = 0.0
	var regex_move = RegEx.new()
	var regex_pickup = RegEx.new()
	var regex_open = RegEx.new()
	var regex_close = RegEx.new()
	var regex_curr_loc = RegEx.new()

	# Updated regex to support curly braces and floating-point numbers
	regex_move.compile("{\\s*move\\((-?\\d+\\.?\\d*),\\s*(-?\\d+\\.?\\d*)\\)\\s*}")
	regex_pickup.compile("{\\s*pickup\\(([^)]+)\\)\\s*}")
	regex_open.compile("{\\s*open\\(([^)]+)\\)\\s*}")
	regex_close.compile("{\\s*close\\(([^)]+)\\)\\s*}")
	regex_curr_loc.compile("{\\s*current_location\\((-?\\d+\\.?\\d*),\\s*(-?\\d+\\.?\\d*)\\)\\s*}")
	
	print("[Player] Parsing LLM response.")
	
	# Process move command
	var match_move = regex_move.search(response)
	if match_move:
		
		autonav = true
		x = match_move.get_string(1).to_float()
		y = match_move.get_string(2).to_float()
		autonav_cmd[0] = x
		autonav_cmd[1] = y
		
		print("[Player] Moving to: ", str(Vector2(x,y)))
		command_display.text = "move("+str(x)+","+str(y)+")"
		cmd_disp_timer.start()
		
		# Remove the move command from the response text
		response = response.replace(match_move.get_string(0), "")

	# Process pickup command
	var match_pickup = regex_pickup.search(response)
	if match_pickup:
		var item_to_pickup = match_pickup.get_string(1)
		# Handle the pickup logic here, e.g., add item_to_pickup to inventory
		print("[Player] Picking up: ", item_to_pickup)
		command_display.text = "pickup("+item_to_pickup+")"
		cmd_disp_timer.start()
		
		# Remove the pickup command from the response text
		response = response.replace(match_pickup.get_string(0), " I just picked up a " + item_to_pickup)

	# Process open command
	var match_open = regex_open.search(response)
	if match_open:
		emit_signal("chest_command",response)
		var item_to_open = match_open.get_string(1)
		# Handle the open logic here, e.g., open item_to_open
		print("[Player] Opening: ", item_to_open)
		command_display.text = "open("+item_to_open+")"
		cmd_disp_timer.start()
		
		# Remove the open command from the response text
		response = response.replace(match_open.get_string(0), " Trying to open the " + item_to_open)
	
	# Process close command
	var match_close = regex_close.search(response)
	if match_close:
		emit_signal("chest_command",response)
		var item_to_close = match_close.get_string(1)
		# Handle the close logic here, e.g., open item_to_close
		print("[Player] Closing: ", item_to_close)
		command_display.text = "close("+item_to_close+")"
		cmd_disp_timer.start()
		
		# Remove the close command from the response text
		response = response.replace(match_close.get_string(0), " Trying to close the " + item_to_close)
		
	# Process current_location command
	var match_curr_loc = regex_curr_loc.search(response)
	if match_curr_loc:
		x = match_curr_loc.get_string(1).to_float()
		y = match_curr_loc.get_string(2).to_float()
		
		print("[Player] Current Location: ", str(Vector2(x,y)))
		command_display.text = "curr_loc("+str(x)+","+str(y)+")"
		cmd_disp_timer.start()
		
		# Remove the move command from the response text
		response = response.replace(match_curr_loc.get_string(0), "")

	return response.strip_edges()

func clear_chat():
	talking = false
	chat_timer.stop()
	DisplayServer.tts_stop()
	rich_text_label.clear()
	tts.tts_busy = false
	tts.tts_queue.clear()

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
	print("[Player] Body Name: ", body.name)
	print("[Player] Body Type: ", typeof(body))
	
func print_full_body_details(body):
	# Print basic metadata
	print("[Player] Body Name: ", body.name)
	print("[Player] Body Type: ", typeof(body))
	if body.has_method("get_position"):
		print("[Player] Body Position: ", body.get_position())
	else:
		print("[Player] Body Position: Not available")
	
	# If the body has a velocity (like CharacterBody2D or RigidBody2D)
	if body.has_method("get_velocity"):
		print("[Player] Body Velocity: ", body.get_velocity())
	else:
		print("[Player] Body Velocity: Not available")
	
	# Print any custom properties (if you have any)
	if body.has_method("get_custom_metadata"):
		print("[Player] Custom Metadata: ", body.get_custom_metadata())

	# Print all properties of the body (optional, can be verbose)
	var body_properties = body.get_property_list()
	for property in body_properties:
		var property_name = property.name
		var property_value = body.get(property_name)
		print("[Player] %s: %s" % [property_name, str(property_value)])

func _on_chat_timer_timeout():
	rich_text_label.clear()
	print("[Player] clear chat") # Replace with function body.

func player():
	pass

func _on_user_input_text_submitted(text):
	send_prompt_to_llama(text)
	user_input.clear()

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
		animation_handler("left")
	elif vel.y > 0:
		animation_handler("down")
	elif vel.y < 0: 
		animation_handler("up")
	else:
		animation_handler("idle")
		
# Helper function to round a float to a specific number of decimal places
func round_to_decimal_places(value, places):
	var factor = pow(10, places)
	return round(value * factor) / factor

var pos_update_once = true
func _on_position_response_timer_timeout():
	#var x = round_to_decimal_places(global_position.x,0)
	#var y = round_to_decimal_places(global_position.y,0)
	#var tmp = POS_UPDATE_MSG+"("+str(x)+","+str(y)+")"
	#print("[Player] Sending position to LLM: ",tmp)
	#send_prompt_to_llama(tmp)
	#position_response_timer.start()


	if velocity.length_squared() > 0:
		print("[Player] moving")
		position_response_timer.start()
		pos_update_once = true
		return

	if pos_update_once == true:
		pos_update_once = false
		var x = round_to_decimal_places(global_position.x,0)
		var y = round_to_decimal_places(global_position.y,0)
		var tmp = POS_UPDATE_MSG+"("+str(x)+","+str(y)+")}"
		print("[Player] Sending position to LLM: ",tmp)
		send_prompt_to_llama(tmp)
		
func _on_cmd_disp_timer_timeout():
	command_display.text = ""
