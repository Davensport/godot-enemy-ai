class_name EnemyMovementComponent
extends Node

@export_group("Settings")
@export var speed: float = 4.0
@export var acceleration: float = 10.0 # Added to match Resource/BaseEnemy usage
@export var aggro_range: float = 15.0
@export var stop_distance: float = 1.5 # How close to get before stopping to attack

@export_group("References")
@export var actor: CharacterBody3D
@export var nav_agent: NavigationAgent3D

var target: Node3D = null

func _ready():
	# Optimize path updates (don't calculate every single frame)
	var timer = Timer.new()
	timer.wait_time = 0.2 # Update path 5 times a second
	timer.autostart = true
	timer.timeout.connect(_update_path_target)
	add_child(timer)

# --- NEW FUNCTION FOR RESOURCE SYSTEM ---
func initialize(new_speed: float, new_accel: float):
	speed = new_speed
	acceleration = new_accel
	# Note: If you want to sync 'stop_distance' with 'attack_range' from the stats,
	# you could add a third argument here, but usually keeping stop_distance
	# separate is fine (you want to stop slightly closer than your max attack range).

func set_target(new_target: Node3D):
	target = new_target

func _update_path_target():
	if target and is_instance_valid(target):
		nav_agent.target_position = target.global_position

func get_chase_velocity() -> Vector3:
	if not target or not is_instance_valid(target):
		return Vector3.ZERO
		
	# 1. Check distance to player
	var distance = actor.global_position.distance_to(target.global_position)
	
	# If player is too far, ignore them
	# Note: The BaseEnemy State Machine handles this too, but this is a good safety check
	if distance > aggro_range:
		return Vector3.ZERO
		
	# If we are close enough to attack, stop moving
	if distance <= stop_distance:
		return Vector3.ZERO

	# 2. Calculate Path
	# This gets the next point on the navigation mesh
	var next_path_position = nav_agent.get_next_path_position()
	var current_position = actor.global_position
	
	# Calculate direction vector
	var direction = (next_path_position - current_position).normalized()
	
	# Calculate velocity (Speed * Direction)
	# If you want to use 'acceleration' later, you would interpolate velocity here.
	# For now, instant speed is snappy and good for simple AI.
	var new_velocity = direction * speed
	
	# Remove Y (vertical) velocity so gravity can handle falling later
	new_velocity.y = 0 
	
	return new_velocity

func look_at_target():
	if target and is_instance_valid(target):
		var target_pos = target.global_position
		target_pos.y = actor.global_position.y # Flatten height
		
		# FIX: Check squared distance (faster than distance) to avoid zero-length vector errors
		# 0.001 is a tiny safety margin
		if actor.global_position.distance_squared_to(target_pos) > 0.001:
			actor.look_at(target_pos, Vector3.UP)
