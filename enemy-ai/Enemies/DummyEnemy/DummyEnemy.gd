class_name DummyEnemy
extends CharacterBody3D

# --- Configuration ---
@export_group("Stats & Settings")
@export var stats: EnemyStats
@export var auto_respawn: bool = true
@export var respawn_time: float = 5.0
@export var gravity: float = 9.8

# --- Components (Adjust paths if your scene tree is different) ---
@onready var state_machine: StateMachine = $StateMachine
@onready var movement_component: Node = $MovementComponent
@onready var combat_component: Node = $CombatComponent
@onready var health_component: Node = $HealthComponent
@onready var visuals_container: Node3D = $Visuals # Assumed container for mesh
@onready var animation_player: AnimationPlayer = $Visuals/AnimationPlayer 
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# --- Runtime State ---
var player_target: Node3D = null
var home_position: Vector3

func _ready():
	# Store the spawn point so we can wander around it later
	home_position = global_position
	
	# MULTIPLAYER SETUP
	# If we are not the server, disable the State Machine processing.
	# The server calculates logic; clients just sync position/rotation.
	if not is_multiplayer_authority():
		set_physics_process(false)
		state_machine.set_physics_process(false)
		state_machine.set_process(false)
		return

func _physics_process(delta):
	# 1. Apply Gravity (if not flying)
	if not is_on_floor() and (stats and not stats.is_flying):
		velocity.y -= gravity * delta

	# 2. Movement is calculated by the StateMachine/States before this runs
	# The States modify 'velocity', and here we execute the move.
	move_and_slide()

# --- AI Helper Functions ---

# The "Weighted Random" targeting logic
func get_weighted_player_target() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	
	var valid_candidates = []
	var total_weight: float = 0.0
	
	for player in players:
		# check validity (and ensure they aren't dead/spectating)
		if not is_instance_valid(player):
			continue
		if "is_dead" in player and player.is_dead:
			continue
			
		var dist = global_position.distance_to(player.global_position)
		
		# Weight Formula: 1.0 / Distance
		# Closer players get drastically higher weights.
		# max(dist, 1.0) prevents division by zero.
		var weight = 1.0 / max(dist, 1.0) 
		
		valid_candidates.append({"node": player, "weight": weight})
		total_weight += weight
	
	if valid_candidates.is_empty():
		return null
		
	# Roulette Wheel Selection
	var random_point = randf_range(0.0, total_weight)
	var current_sum = 0.0
	
	for candidate in valid_candidates:
		current_sum += candidate.weight
		if random_point <= current_sum:
			return candidate.node
	
	# Fallback (rare float precision edge case)
	return valid_candidates[0].node

# --- Visuals ---

func play_animation(anim_name: String):
	# In a full multiplayer setup, you might want to wrap this in an RPC
	# so clients play the attack animation at the exact same time.
	# For now, simple playback:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name, 0.2) # 0.2s blend time

func rotate_smoothly(target_velocity: Vector3, delta: float):
	if target_velocity.length_squared() < 0.01:
		return
		
	var look_dir = Vector2(target_velocity.z, target_velocity.x)
	var current_angle = rotation.y
	var target_angle = look_dir.angle()
	
	rotation.y = lerp_angle(current_angle, target_angle, stats.turn_speed * delta)
