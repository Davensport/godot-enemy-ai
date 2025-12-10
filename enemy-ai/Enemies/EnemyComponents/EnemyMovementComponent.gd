class_name EnemyMovementComponent
extends Node

@export_group("References")
@export var actor: CharacterBody3D
@export var nav_agent: NavigationAgent3D

# Internal settings
var speed: float = 4.0
var acceleration: float = 10.0
var stop_distance: float = 1.5

# Target Management
var target: Node3D = null
var target_pos_override: Vector3 = Vector3.ZERO
var use_override: bool = false

func _ready():
	# Optimize path updates
	var timer = Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	timer.timeout.connect(_update_path_target)
	add_child(timer)
	
	nav_agent.path_desired_distance = 1.0 
	nav_agent.target_desired_distance = 1.0
	nav_agent.avoidance_enabled = true 

# Initialize directly from the Resource
func initialize(stats: EnemyStats):
	speed = stats.move_speed
	acceleration = stats.acceleration
	stop_distance = stats.attack_range * 0.9 

func set_target(new_target: Node3D):
	target = new_target
	use_override = false

func set_target_position(pos: Vector3):
	target = null
	target_pos_override = pos
	use_override = true

func _update_path_target():
	if use_override:
		nav_agent.target_position = target_pos_override
	elif target and is_instance_valid(target):
		nav_agent.target_position = target.global_position

func get_chase_velocity(preserve_height: bool = false) -> Vector3:
	# If we have no valid target/override, stop.
	if not use_override and (not target or not is_instance_valid(target)):
		return Vector3.ZERO

	# Check distance based on what we are following
	var current_dest = target_pos_override if use_override else target.global_position
	var distance = actor.global_position.distance_to(current_dest)
	
	# Stop if we are close enough (mainly for chasing)
	if not use_override and distance <= stop_distance:
		return Vector3.ZERO

	# Pathfinding Logic
	var next_path_position = nav_agent.get_next_path_position()
	var current_position = actor.global_position
	var direction = (next_path_position - current_position).normalized()
	
	var new_velocity = direction * speed
	
	if not preserve_height:
		new_velocity.y = 0 
	
	return new_velocity

func look_at_target():
	var target_pos = Vector3.ZERO
	if use_override:
		target_pos = target_pos_override
	elif target and is_instance_valid(target):
		target_pos = target.global_position
	else:
		return

	target_pos.y = actor.global_position.y # Flatten
	if actor.global_position.distance_squared_to(target_pos) > 0.1:
		actor.look_at(target_pos, Vector3.UP)
