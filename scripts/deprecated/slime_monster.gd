extends CharacterBody2D

var target = null #This sets player as target. remove later

var speed = 50
var acceleration = 5
var state = "idle"
var searchTimerKick = false

@export var search_points = [Vector2(-127, 232), Vector2(126, 222)]

var current_search_point_index = 0
var default_scale = Vector2.ZERO

@onready var navigation_agent_2d = $Navigation/NavigationAgent2D
@onready var target_detect_range = $"Target Detection Area/TargetDetectRange"
@onready var search_timer = $"Target Detection Area/SearchTimer"

func _ready():
	target = null
	searchTimerKick = true
	state = "idle"
	default_scale = target_detect_range.scale # save default scale of detection range
	

func _process(delta):
	if state == "searching":
		target_detect_range.scale = target_detect_range.scale.lerp(default_scale, 0.01)
		agent_nav(search_points[current_search_point_index], delta)
		update_search_points(search_points[current_search_point_index],search_points)
		
		if searchTimerKick == true:
			print("start timer")
			search_timer.start()
			searchTimerKick = false
			
	elif state == "hunting":
		target_detect_range.scale = target_detect_range.scale.lerp(Vector2(2, 2), 0.01)
		agent_nav(navigation_agent_2d.target_position, delta)	
		search_timer.stop()	
	else:
		animation_handler("idle")

func _on_target_detection_area_body_entered(body):
	#detect if player entered detection zone
	if body.has_method("player"):
		target = body
		state = "hunting"
		print("[Purply] Contact made with player!!") # Replace with function body.
	
func _on_target_detection_area_body_exited(body):
	body = body
	print("[Purply] Lost sight. Searching")
	target = null
	state = "searching" # Replace with function body.


func agent_nav(target_position, delta):
	
	var direction = target_position - global_position
	direction = direction.normalized()
	
	velocity = velocity.lerp(direction * speed , acceleration * delta)
	
	move_and_slide()

	# Round velocity to 4 decimal places
	var vel = velocity
	vel.x = round_to_decimal_places(vel.x, 1)
	vel.y = round_to_decimal_places(vel.y, 1)

	# Update the animation based on motion
	update_animation(vel)

func update_search_points(target_position,point_array):
	# Check if the enemy has reached the target position
	if position.distance_to(target_position) < 5:
		# Move to the next patrol point
		current_search_point_index = (current_search_point_index + 1) % point_array.size()
	
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

# Helper function to round a float to a specific number of decimal places
func round_to_decimal_places(value, places):
	var factor = pow(10, places)
	return round(value * factor) / factor

func _on_timer_timeout():
	if target != null:
		navigation_agent_2d.target_position = target.global_position # Replace with function body.

func _on_search_timer_timeout():
	print("Can't find anything, going to sleep zzz...")
	state = "idle" # Replace with function body.
	searchTimerKick = true
	
func slime_monster():
	pass
