class_name DummyEnemy
extends CharacterBody3D

# --- 1. DATA RESOURCE ---
@export var stats: EnemyStats 

# --- 2. SETTINGS ---
@export_group("Settings")
@export var auto_respawn: bool = false 
@export var respawn_time: float = 3.0

# --- 3. COMPONENT REFERENCES ---
@export_group("References")
@export var health_component: HealthComponent
@export var movement_component: EnemyMovementComponent
@export var combat_component: EnemyCombatComponent 
@export var visuals_container: Node3D 
@export var collision_shape: CollisionShape3D
@onready var health_bar = $EnemyHealthbar3D

# --- 4. STATE MACHINE ---
@onready var state_machine = $StateMachine

# --- 5. ANIMATION SYSTEM ---
var _animation_players: Array[AnimationPlayer] = []

# --- 6. SHARED STATE DATA ---
var player_target: Node3D
var flight_offset_time: float = 0.0 
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var home_position: Vector3 

# --- 7. MULTIPLAYER LOGIC ---
var target_check_timer: float = 0.0
const TARGET_CHECK_INTERVAL: float = 0.5

# --- SETUP ---
func _ready():
	if not stats:
		push_error("CRITICAL: No EnemyStats resource assigned to " + name)
		return

	# Capture Spawn Point
	home_position = global_position 

	initialize_from_stats()
	_connect_signals()
	
	if stats.is_flying:
		flight_offset_time = randf() * 10.0
	
	# Only the Server needs to find targets initially
	if multiplayer.is_server():
		await get_tree().physics_frame
		find_player()

func _physics_process(delta):
	# 1. CLIENT STOP CHECK
	# If we are NOT the server, stop thinking. Let the MultiplayerSynchronizer move us.
	if not multiplayer.is_server():
		return

	# 2. SERVER LOGIC
	# A. Periodic Targeting Check (Find closest player)
	target_check_timer -= delta
	if target_check_timer <= 0.0:
		target_check_timer = TARGET_CHECK_INTERVAL
		find_player()

	# B. Standard Physics
	var is_dead = state_machine.current_state and state_machine.current_state.name.to_lower() == "death"
	
	if not stats.is_flying and not is_on_floor() and not is_dead:
		velocity.y -= gravity * delta

	move_and_slide()

func initialize_from_stats():
	if stats.is_flying:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		axis_lock_linear_y = false 
	else:
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	if health_component: health_component.initialize(stats.max_health)
	
	if movement_component: movement_component.initialize(stats)
	
	if combat_component:
		var proj_scene = stats.projectile_scene if "projectile_scene" in stats else null
		var proj_speed = stats.projectile_speed if "projectile_speed" in stats else 0.0
		combat_component.initialize(stats.attack_damage, stats.attack_range, stats.attack_rate, proj_scene, proj_speed)
		
	if stats.model_scene and visuals_container:
		for child in visuals_container.get_children():
			child.queue_free()
		
		var new_model = stats.model_scene.instantiate()
		visuals_container.add_child(new_model)
		visuals_container.scale = Vector3.ONE * stats.scale
		
		_animation_players.clear()
		_find_all_animation_players(new_model)

	if collision_shape:
		collision_shape.scale = Vector3.ONE * stats.scale
		
	if "model_rotation_y" in stats and visuals_container and visuals_container.get_child_count() > 0:
		visuals_container.get_child(0).rotation_degrees.y = stats.model_rotation_y
		
	if health_component:
		_update_ui(health_component.current_health, health_component.max_health)

func _connect_signals():
	if health_component:
		health_component.on_death.connect(_on_death_event)
		health_component.on_damage_taken.connect(_on_damage_event)
		health_component.on_health_changed.connect(_update_ui)
		
	if combat_component:
		combat_component.on_attack_performed.connect(_on_attack_visuals)
	
	# SignalBus connections (removed player_spawned since we now poll automatically)
	# SignalBus.player_died.connect(_on_player_died) 

## --- NETWORKED ANIMATION FUNCTIONS (RPCs) ---

func play_animation(anim_name: String):
	# If we are the Server, we tell everyone (including ourselves) to play the animation.
	if multiplayer.is_server():
		_rpc_play_animation.rpc(anim_name)

# @rpc("call_local") means: Run this on the Server AND send it to all Clients.
# @rpc("reliable") means: Make sure this packet definitely arrives.
@rpc("call_local", "reliable")
func _rpc_play_animation(anim_name: String):
	if _animation_players.is_empty() or anim_name == "":
		return

	for anim_player in _animation_players:
		if anim_player.has_animation(anim_name):
			# Optimization: If already playing this animation, don't restart it
			if anim_player.current_animation == anim_name and anim_player.is_playing():
				continue 
			anim_player.play(anim_name, 0.2)
		else:
			anim_player.stop()

func rotate_smoothly(target_direction: Vector3, delta: float):
	var horizontal_dir = Vector3(target_direction.x, 0, target_direction.z)
	if horizontal_dir.length_squared() < 0.001: return
	
	var target_look_pos = global_position + horizontal_dir
	var current_transform = global_transform
	var target_transform = current_transform.looking_at(target_look_pos, Vector3.UP)
	
	var current_y = rotation.y
	var target_y = target_transform.basis.get_euler().y
	var turn_speed = stats.turn_speed if "turn_speed" in stats else 10.0
	
	rotation.y = lerp_angle(current_y, target_y, turn_speed * delta)

# --- REVISED TARGETING LOGIC (SERVER ONLY) ---
func find_player():
	if not multiplayer.is_server():
		return

	var all_players = get_tree().get_nodes_in_group("player")
	var closest_player: Node3D = null
	var closest_dist: float = 99999.0

	for player in all_players:
		if not is_instance_valid(player):
			continue
			
		var dist = global_position.distance_to(player.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_player = player
	
	# Only update if the target has actually changed
	if closest_player != player_target:
		player_target = closest_player
		if movement_component: movement_component.set_target(player_target)
		if combat_component: combat_component.set_target(player_target)

# --- INTERNAL HELPERS ---
func _find_all_animation_players(node: Node):
	if node is AnimationPlayer:
		_animation_players.append(node)
	for child in node.get_children():
		_find_all_animation_players(child)

func _update_ui(current, max_hp):
	if health_bar:
		var safe_max = max(1.0, max_hp)
		health_bar.update_bar(current, safe_max)

func _on_attack_visuals():
	# Server detects the attack -> tells everyone to do the "Lunge" tween
	if multiplayer.is_server():
		_rpc_attack_visuals.rpc()
	
	## Logic (Damage) still happens here
	#if stats:
		#SignalBus.enemy_attack_occurred.emit(self, stats.attack_damage)

@rpc("call_local", "reliable")
func _rpc_attack_visuals():
	# Visual "Lunge" effect synced on all clients
	if visuals_container:
		var tween = create_tween()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, -0.5), 0.1).as_relative()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, 0.5), 0.2).as_relative()

# --- EVENT HANDLERS ---
func _on_damage_event(_amount):
	_update_ui(health_component.current_health, health_component.max_health)
	
	if state_machine.current_state and state_machine.current_state.name.to_lower() == "death":
		return
		
	state_machine.force_change_state("hit")

func take_damage(amount: float):
	if health_component:
		health_component.take_damage(amount)

func _on_death_event():
	state_machine.force_change_state("death")
	SignalBus.enemy_died.emit(self)
