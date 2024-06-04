extends Node2D

@onready var animated_sprite_2d = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	animated_sprite_2d.play("closed")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_george_player_command(response):
	print("++++++##############+++++++++++++#######++++++++")
	var regex_open = RegEx.new()
	regex_open.compile("{\\s*open\\(([^)]+)\\)\\s*}")
	var regex_close = RegEx.new()
	regex_close.compile("{\\s*close\\(([^)]+)\\)\\s*}")
	
	# Process open command
	var match_open = regex_open.search(response)
	if match_open:
		animated_sprite_2d.play("chest_opening")
		var item_to_open = match_open.get_string(1)
		# Handle the open logic here, e.g., open item_to_open
		print("["+item_to_open+"] Opening!")
		
		# Remove the open command from the response text
		response = response.replace(match_open.get_string(0), " Opened the " + item_to_open)
		
	# Process close command
	var match_close = regex_close.search(response)
	if match_close:
		animated_sprite_2d.play("chest_closing")
		var item_to_close = match_close.get_string(1)
		# Handle the open logic here, e.g., open item_to_open
		print("["+item_to_close+"] Closing!")
		
		# Remove the open command from the response text
		response = response.replace(match_close.get_string(0), " Closed the " + item_to_close)
		
