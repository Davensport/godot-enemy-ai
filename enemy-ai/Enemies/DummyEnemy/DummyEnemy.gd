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
# This is the new "Brain" of the enemy
@onready var state_machine = $StateMachine

# --- 5. ANIMATION SYSTEM ---
var _animation_players: Array[AnimationPlayer] = []

# --- 6. SHARED STATE DATA (Accessed by Child States) ---
# These variables are public so states (Chase, Attack) can read/write them.
var player_target: Node3D
var flight_offset_time: float = 0.0 # Used by Chase/Fly states for bobbing
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- SETUP ---
func _ready():
	if not stats:
		push_error("CRITICAL: No EnemyStats resource assigned to " + name)
		return

	initialize_from_stats()
	_connect_signals()
	
	# Initialize Flight Offset randomly so enemies don't bob in perfect sync
	if stats.is_flying:
		flight_offset_time = randf() * 10.0
	
	# Initial Search
	await get_tree().physics_frame
	find_player()

# --- PHYSICS LOOP ---
func _physics_process(delta):
	# The State Machine handles specific logic (Chasing, Attacking, Idling).
	# The Main Script handles GLOBAL physics rules (Gravity).
	
	# Check if dead so we don't apply gravity to a corpse (unless desired)
	var is_dead = state_machine.current_state and state_machine.current_state.name.to_lower() == "death"
	
	if not stats.is_flying and not is_on_floor() and not is_dead:
		velocity.y -= gravity * delta

	# We do NOT calculate velocity here. The active State does that.
	# We just apply the final result.
	move_and_slide()

# --- INITIALIZATION HELPER ---
func initialize_from_stats():
	# Movement Mode
	if stats.is_flying:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		axis_lock_linear_y = false 
	else:
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	# Initialize Components
	if health_component: health_component.initialize(stats.max_health)
	if movement_component: movement_component.initialize(stats.move_speed, stats.acceleration)
	
	if combat_component:
		var proj_scene = stats.projectile_scene if "projectile_scene" in stats else null
		var proj_speed = stats.projectile_speed if "projectile_speed" in stats else 0.0
		combat_component.initialize(stats.attack_damage, stats.attack_range, stats.attack_rate, proj_scene, proj_speed)
		
	# Visuals Setup
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

# --- SIGNAL CONNECTIONS ---
func _connect_signals():
	if health_component:
		health_component.on_death.connect(_on_death_event)
		health_component.on_damage_taken.connect(_on_damage_event)
		health_component.on_health_changed.connect(_update_ui)
		
	if combat_component:
		combat_component.on_attack_performed.connect(_on_attack_visuals)

	SignalBus.player_spawned.connect(_on_player_spawned)
	SignalBus.player_died.connect(_on_player_died)

# --- PUBLIC HELPER FUNCTIONS (Called by States) ---
# These act as a utility library for your states so you don't rewrite code.

func play_animation(anim_name: String):
	if _animation_players.is_empty() or anim_name == "":
		return
	for anim_player in _animation_players:
		if anim_player.has_animation(anim_name):
			# Do not restart the same animation if it is already looping
			if anim_player.current_animation == anim_name and anim_player.is_playing():
				return 
			anim_player.play(anim_name, 0.2) 
			return

func rotate_smoothly(target_direction: Vector3, delta: float):
	# Flatten direction (we only rotate on Y axis)
	var horizontal_dir = Vector3(target_direction.x, 0, target_direction.z)
	if horizontal_dir.length_squared() < 0.001: return
	
	var target_look_pos = global_position + horizontal_dir
	var current_transform = global_transform
	var target_transform = current_transform.looking_at(target_look_pos, Vector3.UP)
	
	var current_y = rotation.y
	var target_y = target_transform.basis.get_euler().y
	var turn_speed = stats.turn_speed if "turn_speed" in stats else 10.0
	
	rotation.y = lerp_angle(current_y, target_y, turn_speed * delta)

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_target = players[0]
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
	if visuals_container:
		var tween = create_tween()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, -0.5), 0.1).as_relative()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, 0.5), 0.2).as_relative()
	if stats:
		SignalBus.enemy_attack_occurred.emit(self, stats.attack_damage)

# --- EVENT HANDLERS (State Interrupts) ---

func _on_damage_event(_amount):
	_update_ui(health_component.current_health, health_component.max_health)
	
	# If we are already dead, do nothing
	if state_machine.current_state and state_machine.current_state.name.to_lower() == "death":
		return
		
	# Optional: Force a "Hit" state if desired
	state_machine.force_change_state("hit")

func _on_death_event():
	# Force the state machine into the Death state
	# This overrides whatever the enemy was doing (Chasing/Attacking)
	state_machine.force_change_state("death")
	SignalBus.enemy_died.emit(self)

func _on_player_spawned():
	find_player()

func _on_player_died():
	player_target = null
	# Force back to Idle
	state_machine.force_change_state("idle")
