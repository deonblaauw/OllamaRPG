extends CharacterBody2D

var target = null #This sets player as target. remove later

var speed = 50
var acceleration = 5
var state = "idle"

@export var patrol_points = [Vector2(-127, 232), Vector2(126, 222)]
var current_point_index = 0
var default_scale = Vector2.ZERO

@onready var navigation_agent_2d = $Navigation/NavigationAgent2D
@onready var target_detect_range = $"Target Detection Area/TargetDetectRange"

func _ready():
	target = null
	state = "patrolling"
	default_scale = target_detect_range.scale # save default scale of detection range
	$AnimatedSprite2D.play("idle")
	

func _process(delta):
	if state == "patrolling":
		target_detect_range.scale = target_detect_range.scale.lerp(default_scale, 0.01)
		agent_nav(patrol_points[current_point_index], delta)
		update_patrol_points(patrol_points[current_point_index])
	elif state == "hunting":
		target_detect_range.scale = target_detect_range.scale.lerp(Vector2(2, 2), 0.01)
		agent_nav(navigation_agent_2d.target_position, delta)
	else:
		animation_handler("idle")

func _on_timer_timeout():
	if target != null:
		navigation_agent_2d.target_position = target.global_position # Replace with function body.

func _on_target_detection_area_body_entered(body):
	#print_full_body_details(body)
	if body.name == "Player":
		target = body
		state = "hunting"
		print("[Purply] Contact made with player!!") # Replace with function body.
	
func _on_target_detection_area_body_exited(body):
	body = body
	print("[Purply] Lost sight. Patrolling")
	target = null
	state = "patrolling" # Replace with function body.


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

	
		
func update_patrol_points(target_position):
	# Check if the enemy has reached the target position
	if position.distance_to(target_position) < 5:
		# Move to the next patrol point
		current_point_index = (current_point_index + 1) % patrol_points.size()
	
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
		$AnimatedSprite2D.play("moving")
	elif direction == "left":
		$AnimatedSprite2D.flip_h = true
		$AnimatedSprite2D.play("moving")
	elif direction == "up":
		$AnimatedSprite2D.play("moving")
	elif direction == "down":
		$AnimatedSprite2D.play("moving")
	elif direction == "idle":
		$AnimatedSprite2D.play("idle")
	else:
		$AnimatedSprite2D.play("idle")

# Helper function to round a float to a specific number of decimal places
func round_to_decimal_places(value, places):
	var factor = pow(10, places)
	return round(value * factor) / factor


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
