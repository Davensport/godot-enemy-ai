class_name DummyEnemy
extends CharacterBody3D

# --- 1. DATA RESOURCE ---
@export var stats: EnemyStats 

# --- 2. SETTINGS ---
@export_group("Settings")
@export var auto_respawn: bool = false # turned this off for testing, is an export var for each enemy however if you want to change it there.
 # dont think this should really ever be on, except like a practice dummy or something.
@export var respawn_time: float = 3.0

# --- 3. COMPONENT REFERENCES ---
@export_group("References")
@export var health_component: HealthComponent
@export var movement_component: EnemyMovementComponent
@export var combat_component: EnemyCombatComponent 
@export var visuals_container: Node3D 
@export var collision_shape: CollisionShape3D
@onready var health_bar = $EnemyHealthbar3D

# --- 4. STATE MACHINE & TIMERS ---
enum State { IDLE, CHASE, ATTACK, DEAD, RESPAWNING }
var current_state: State = State.IDLE

var attack_timer: float = 0.0 
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_target: Node3D

# --- 5. ANIMATION SYSTEM (Refactored) ---
# We no longer hardcode specific players. We store a list of ALL players found.
var _animation_players: Array[AnimationPlayer] = []

# --- SETUP ---
func _ready():
	if stats:
		initialize_from_stats()
	else:
		push_warning("No EnemyStats resource assigned to " + name)

	if health_component:
		health_component.on_death.connect(_on_death)
		health_component.on_damage_taken.connect(_on_hit)
		health_component.on_health_changed.connect(_update_ui)
		_update_ui(health_component.current_health, health_component.max_health)
		
	if combat_component:
		combat_component.on_attack_performed.connect(_on_attack_visuals)

	SignalBus.player_spawned.connect(_on_player_spawned)
	SignalBus.player_died.connect(_on_player_died)
	call_deferred("find_player")

# --- INITIALIZATION LOGIC ---
func initialize_from_stats():
	# 0. Physics Mode
	if stats.is_flying:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		axis_lock_linear_y = false 
	else:
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	# 1. Initialize Components
	if health_component: health_component.initialize(stats.max_health)
	if movement_component: movement_component.initialize(stats.move_speed, stats.acceleration)
	
	if combat_component:
		var proj_scene = null
		var proj_speed = 0.0
		# Safety check using 'in' in case resource isn't updated yet
		if "projectile_scene" in stats:
			proj_scene = stats.projectile_scene
			proj_speed = stats.projectile_speed
			
		combat_component.initialize(stats.attack_damage, stats.attack_range, stats.attack_rate, proj_scene, proj_speed)
		
	# 2. LOAD VISUALS & FIND ANIMATIONS
	if stats.model_scene and visuals_container:
		# Clear existing placeholders
		for child in visuals_container.get_children():
			child.queue_free()
		
		# Instantiate new model
		var new_model = stats.model_scene.instantiate()
		visuals_container.add_child(new_model)
		visuals_container.scale = Vector3.ONE * stats.scale
		
		# NEW: Dynamic Animation Discovery
		_animation_players.clear()
		_find_all_animation_players(new_model)

	if collision_shape:
		collision_shape.scale = Vector3.ONE * stats.scale

	if "model_rotation_y" in stats and visuals_container and visuals_container.get_child_count() > 0:
		visuals_container.get_child(0).rotation_degrees.y = stats.model_rotation_y

# --- NEW RECURSIVE SEARCH FUNCTION ---
func _find_all_animation_players(node: Node):
	if node is AnimationPlayer:
		_animation_players.append(node)
	
	for child in node.get_children():
		_find_all_animation_players(child)

# --- NEW UNIVERSAL PLAY FUNCTION ---
func play_animation(anim_name: String):
	if _animation_players.is_empty() or anim_name == "":
		return
		
	# Look through all found players
	for anim_player in _animation_players:
		if anim_player.has_animation(anim_name):
			# If found, play it (with blend) and return
			# 0.2 is the default blend time, you could also add this to EnemyStats
			anim_player.play(anim_name, 0.2) 
			return

# --- MAIN PHYSICS LOOP ---
func _physics_process(delta):
	if not stats.is_flying and not is_on_floor():
		velocity.y -= gravity * delta

	if attack_timer > 0:
		attack_timer -= delta

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DEAD, State.RESPAWNING:
			pass 
	
	_update_animation_state()
	move_and_slide()

# --- STATE FUNCTIONS ---

func _process_idle(_delta):
	velocity.x = move_toward(velocity.x, 0, 1.0)
	velocity.z = move_toward(velocity.z, 0, 1.0)
	if stats.is_flying:
		velocity.y = move_toward(velocity.y, 0, 1.0)
	
	if player_target and is_instance_valid(player_target):
		current_state = State.CHASE

func _process_chase(delta):
	if not player_target or not is_instance_valid(player_target):
		current_state = State.IDLE
		player_target = null 
		return

	var distance = global_position.distance_to(player_target.global_position)
	
	# --- MOVEMENT ---
	if stats.is_flying:
		# Fly towards head height
		var target_pos = player_target.global_position + Vector3(0, 1.5, 0)
		var direction = (target_pos - global_position).normalized()
		
		# Smooth Acceleration
		var turn_rate = stats.turn_speed if "turn_speed" in stats else 5.0
		velocity = velocity.lerp(direction * stats.move_speed, turn_rate * delta)
		
		_rotate_smoothly(velocity, delta)
		
	else:
		if movement_component:
			var chase_velocity = movement_component.get_chase_velocity()
			velocity.x = move_toward(velocity.x, chase_velocity.x, stats.acceleration * delta)
			velocity.z = move_toward(velocity.z, chase_velocity.z, stats.acceleration * delta)
			
			_rotate_smoothly(velocity, delta)

	# --- ATTACK CHECK ---
	var range_check = stats.attack_range if stats else 1.5
	if distance <= range_check:
		current_state = State.ATTACK

func _process_attack(_delta):
	velocity.x = move_toward(velocity.x, 0, 1.0)
	velocity.z = move_toward(velocity.z, 0, 1.0)
	if stats.is_flying:
		velocity.y = move_toward(velocity.y, 0, 1.0)
	
	if not player_target or not is_instance_valid(player_target):
		current_state = State.IDLE
		player_target = null
		return

	# Rotate smoothly towards PLAYER
	var dir_to_player = (player_target.global_position - global_position)
	_rotate_smoothly(dir_to_player, _delta)
	
	if attack_timer <= 0:
		if combat_component:
			combat_component.try_attack() 
			
			# NEW: Play attack animation defined in stats
			if "anim_attack" in stats:
				play_animation(stats.anim_attack)
			
			attack_timer = stats.attack_rate if stats else 1.0

	if not player_target or not is_instance_valid(player_target):
		current_state = State.IDLE
		player_target = null
		return

	var distance = global_position.distance_to(player_target.global_position)
	var range_check = stats.attack_range if stats else 1.5
	if distance > range_check + 0.5: 
		current_state = State.CHASE

func _rotate_smoothly(target_direction: Vector3, delta: float):
	var horizontal_dir = Vector3(target_direction.x, 0, target_direction.z)

	if horizontal_dir.length_squared() < 0.001:
		return

	var target_look_pos = global_position + horizontal_dir
	var current_transform = global_transform
	var target_transform = current_transform.looking_at(target_look_pos, Vector3.UP)
	
	var current_y = rotation.y
	var target_y = target_transform.basis.get_euler().y
	
	var turn_speed = stats.turn_speed if "turn_speed" in stats else 10.0
	rotation.y = lerp_angle(current_y, target_y, turn_speed * delta)

# --- HELPER FUNCTIONS ---

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_target = players[0]
		if movement_component: movement_component.set_target(player_target)
		if combat_component: combat_component.set_target(player_target)
		if current_state == State.IDLE:
			current_state = State.CHASE

func take_damage(amount: float): 
	if health_component:
		health_component.take_damage(amount)
	
	# NEW: Play hit animation from stats
	if "anim_hit" in stats:
		play_animation(stats.anim_hit)

func _on_attack_visuals():
	if visuals_container:
		var tween = create_tween()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, -0.5), 0.1).as_relative()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, 0.5), 0.2).as_relative()
	if stats:
		SignalBus.enemy_attack_occurred.emit(self, stats.attack_damage)

func _on_hit(_amount):
	_update_ui(health_component.current_health, health_component.max_health)
	
	# Only do the squash/stretch tween if we DON'T have a hit animation
	# or if we want it to happen alongside the animation
	if not "anim_hit" in stats or stats.anim_hit == "":
		if visuals_container:
			var tween = create_tween()
			tween.tween_property(visuals_container, "scale", Vector3(1.1, 0.9, 1.1), 0.1)
			tween.tween_property(visuals_container, "scale", Vector3.ONE * (stats.scale if stats else 1.0), 0.1)

# --- ANIMATION LOGIC ---
func _update_animation_state():
	if _animation_players.is_empty(): 
		return
	
	# Safety check for properties in case EnemyStats is not fully updated yet
	var has_anim_props = "anim_idle" in stats
	
	if not has_anim_props:
		return

	match current_state:
		State.IDLE:
			play_animation(stats.anim_idle)
		State.CHASE:
			play_animation(stats.anim_move) 
		State.DEAD:
			play_animation(stats.anim_death)

func _update_ui(current, max_hp):
	if health_bar:
		health_bar.update_bar(current, max_hp)

func _on_death():
	current_state = State.DEAD
	SignalBus.enemy_died.emit(self)
	velocity = Vector3.ZERO
	
	if auto_respawn:
		current_state = State.RESPAWNING
		await get_tree().create_timer(respawn_time).timeout
		respawn()
	else:
		# If you have a death animation, wait for it to finish?
		# For now, just wait a moment then free
		await get_tree().create_timer(1.0).timeout
		queue_free()

func respawn():
	health_component.reset_health()
	if visuals_container:
		visuals_container.visible = true
		visuals_container.scale = Vector3.ONE * (stats.scale if stats else 1.0)
	collision_shape.set_deferred("disabled", false)
	_update_ui(health_component.current_health, health_component.max_health)
	current_state = State.IDLE
	find_player()

func _on_player_spawned():
	find_player()

func _on_player_died():
	player_target = null
	current_state = State.IDLE
