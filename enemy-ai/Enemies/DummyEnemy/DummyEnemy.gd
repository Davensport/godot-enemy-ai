#class_name DummyEnemy
#extends CharacterBody3D
#
## --- 1. DATA RESOURCE ---
#@export var stats: EnemyStats # <--- Drag your Resource (Goblin, Spider, etc) here
#
## --- 2. SETTINGS ---
#@export_group("Settings")
#@export var auto_respawn: bool = true
#@export var respawn_time: float = 3.0
#
## --- 3. COMPONENT REFERENCES ---
#@export_group("References")
#@export var health_component: HealthComponent
#@export var movement_component: EnemyMovementComponent
#@export var combat_component: EnemyCombatComponent 
#@export var visuals_container: Node3D # If this is a MeshInstance3D, we can swap the mesh automatically
#@export var collision_shape: CollisionShape3D
#@onready var health_bar = $EnemyHealthbar3D
#
## --- 4. STATE MACHINE & TIMERS ---
#enum State { IDLE, CHASE, ATTACK, DEAD, RESPAWNING }
#var current_state: State = State.IDLE
#
#var attack_timer: float = 0.0
#var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
#var player_target: Node3D
#
#func _ready():
	## A. Initialize Components using the Resource Data
	#if stats:
		#initialize_from_stats()
	#else:
		#push_warning("No EnemyStats resource assigned to " + name + ". Using default component values.")
#
	## B. Connect Component Signals
	#if health_component:
		#health_component.on_death.connect(_on_death)
		#health_component.on_damage_taken.connect(_on_hit)
		#health_component.on_health_changed.connect(_update_ui)
		## Initialize UI immediately
		#_update_ui(health_component.current_health, health_component.max_health)
		#
	#if combat_component:
		#combat_component.on_attack_performed.connect(_on_attack_visuals)
#
	## C. Global Signals
	#SignalBus.player_spawned.connect(_on_player_spawned)
	#SignalBus.player_died.connect(_on_player_died)
		#
	## D. Find Player
	#call_deferred("find_player")
#
## --- INITIALIZATION LOGIC ---
#func initialize_from_stats():
	## 1. Inject Stats into Components
	## Note: You must ensure your Components have these 'initialize' functions!
	#if health_component:
		#health_component.initialize(stats.max_health)
	#
	#if movement_component:
		#movement_component.initialize(stats.move_speed, stats.acceleration)
		#
	#if combat_component:
		#combat_component.initialize(stats.attack_damage, stats.attack_range, stats.attack_rate)
#
	## 2. Update Visuals (Swap Mesh)
	## This allows you to use the same script for a Goblin and a Zombie
	#if stats.mesh and visuals_container is MeshInstance3D:
		#visuals_container.mesh = stats.mesh
	#
	## 3. Apply Scale
	#if visuals_container:
		#visuals_container.scale = Vector3.ONE * stats.scale
#
## --- MAIN PHYSICS LOOP (STATE MACHINE) ---
#func _physics_process(delta):
	## Apply Gravity
	#if not is_on_floor():
		#velocity.y -= gravity * delta
#
	## Code-Based Timer for Attack
	#if attack_timer > 0:
		#attack_timer -= delta
#
	## State Logic
	#match current_state:
		#State.IDLE:
			#_process_idle(delta)
		#State.CHASE:
			#_process_chase(delta)
		#State.ATTACK:
			#_process_attack(delta)
		#State.DEAD, State.RESPAWNING:
			#pass # Do nothing
	#
	#move_and_slide()
#
## --- STATE FUNCTIONS ---
#
#func _process_idle(delta):
	#velocity.x = move_toward(velocity.x, 0, movement_component.speed if movement_component else 1.0)
	#velocity.z = move_toward(velocity.z, 0, movement_component.speed if movement_component else 1.0)
	#
	## Transition: If we have a target, start chasing
	#if player_target:
		#current_state = State.CHASE
#
#func _process_chase(delta):
	#if not player_target or not movement_component:
		#current_state = State.IDLE
		#return
#
	## 1. Get Distance
	#var distance = global_position.distance_to(player_target.global_position)
	#
	## 2. Move
	#var chase_velocity = movement_component.get_chase_velocity()
	#velocity.x = chase_velocity.x
	#velocity.z = chase_velocity.z
	#movement_component.look_at_target()
#
	## 3. Transition: Attack if close enough
	## We use the stats.attack_range directly here
	#var range_check = stats.attack_range if stats else 1.5
	#if distance <= range_check:
		#current_state = State.ATTACK
#
#func _process_attack(delta):
	## Stop moving while attacking
	#velocity.x = move_toward(velocity.x, 0, 1.0)
	#velocity.z = move_toward(velocity.z, 0, 1.0)
	#
	#if not player_target:
		#current_state = State.IDLE
		#return
#
	## Face the player even while attacking
	#if movement_component:
		#movement_component.look_at_target()
#
	## Try to Attack (Managed by Timer)
	#if attack_timer <= 0:
		#if combat_component:
			#combat_component.try_attack() # This triggers the signal/visuals
			#attack_timer = stats.attack_rate if stats else 1.0
#
	## Transition: Go back to chase if player runs away
	#var distance = global_position.distance_to(player_target.global_position)
	#var range_check = stats.attack_range if stats else 1.5
	#
	## Add a small buffer (0.5) to prevent jittering between Chase/Attack
	#if distance > range_check + 0.5: 
		#current_state = State.CHASE
#
## --- HELPER FUNCTIONS ---
#
#func find_player():
	#var players = get_tree().get_nodes_in_group("player")
	#if players.size() > 0:
		#player_target = players[0]
		#if movement_component: movement_component.set_target(player_target)
		#if combat_component: combat_component.set_target(player_target)
		#
		#if current_state == State.IDLE:
			#current_state = State.CHASE
#
#func take_damage(amount: int):
	#if health_component:
		#health_component.take_damage(amount)
#
## --- SIGNALS & VISUALS ---
#
#func _on_attack_visuals():
	## Visual Lunge
	#var tween = create_tween()
	#tween.tween_property(visuals_container, "position", Vector3(0, 0, -0.5), 0.1).as_relative()
	#tween.tween_property(visuals_container, "position", Vector3(0, 0, 0.5), 0.2).as_relative()
	#
	## Global Signal Bus (Great for Sound Managers or FX Managers)
	#if stats:
		#SignalBus.enemy_attack_occurred.emit(self, stats.attack_damage)
#
#func _on_hit(_amount):
	#_update_ui(health_component.current_health, health_component.max_health)
	#
	## Flash Effect
	#var tween = create_tween()
	#tween.tween_property(visuals_container, "scale", Vector3(1.1, 0.9, 1.1), 0.1)
	#tween.tween_property(visuals_container, "scale", Vector3.ONE, 0.1)
#
#func _update_ui(current, max_hp):
	#if health_bar:
		#health_bar.update_bar(current, max_hp)
#
#func _on_death():
	#current_state = State.DEAD
	#SignalBus.enemy_died.emit(self)
	#
	#velocity = Vector3.ZERO
	#visuals_container.visible = false
	#collision_shape.set_deferred("disabled", true)
	#
	#if auto_respawn:
		#current_state = State.RESPAWNING
		#await get_tree().create_timer(respawn_time).timeout
		#respawn()
	#else:
		#queue_free()
#
#func respawn():
	#print("Enemy Respawned")
	#health_component.reset_health()
	#visuals_container.visible = true
	#visuals_container.scale = Vector3.ONE * (stats.scale if stats else 1.0)
	#collision_shape.set_deferred("disabled", false)
	#_update_ui(health_component.current_health, health_component.max_health)
	#
	#current_state = State.IDLE
	#find_player()
#
#func _on_player_spawned():
	#find_player()
#
#func _on_player_died():
	#player_target = null
	#current_state = State.IDLE
class_name DummyEnemy
extends CharacterBody3D

# --- 1. DATA RESOURCE ---
@export var stats: EnemyStats # <--- The Data Container

# --- 2. SETTINGS ---
@export_group("Settings")
@export var auto_respawn: bool = true
@export var respawn_time: float = 3.0

# --- 3. COMPONENT REFERENCES ---
@export_group("References")
@export var health_component: HealthComponent
@export var movement_component: EnemyMovementComponent
@export var combat_component: EnemyCombatComponent 
@export var collision_shape: CollisionShape3D
@onready var health_bar = $EnemyHealthbar3D
@export var visuals_container: Node3D
var anim_player: AnimationPlayer
# --- 4. STATE MACHINE & TIMERS ---
enum State { IDLE, CHASE, ATTACK, DEAD, RESPAWNING }
var current_state: State = State.IDLE

var attack_timer: float = 0.0 # Code-based timer
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_target: Node3D

# --- SETUP ---
func _ready():
	# A. Initialize Components using the Resource Data
	if stats:
		initialize_from_stats()
	else:
		push_warning("No EnemyStats resource assigned to " + name)

	# B. Connect Component Signals
	if health_component:
		health_component.on_death.connect(_on_death)
		health_component.on_damage_taken.connect(_on_hit)
		health_component.on_health_changed.connect(_update_ui)
		# Initialize UI immediately
		_update_ui(health_component.current_health, health_component.max_health)
		
	if combat_component:
		# Connect to your existing visual tween logic
		combat_component.on_attack_performed.connect(_on_attack_visuals)

	# C. Global Signals
	SignalBus.player_spawned.connect(_on_player_spawned)
	SignalBus.player_died.connect(_on_player_died)
		
	# D. Find Player
	call_deferred("find_player")

# --- INITIALIZATION LOGIC (The "Brain") ---
# DummyEnemy.gd

# Update the reference to point to the Container, not a MeshInstance

func initialize_from_stats():
	# 1. Initialize Components (Same as before)
	if health_component: health_component.initialize(stats.max_health)
	if movement_component: movement_component.initialize(stats.move_speed, stats.acceleration)
	if combat_component: combat_component.initialize(stats.attack_damage, stats.attack_range, stats.attack_rate)

	# LOAD THE VISUALS
	if stats.model_scene and visuals_container:
		# Clear old models
		for child in visuals_container.get_children():
			child.queue_free()
		
		# Instantiate new one
		var new_model = stats.model_scene.instantiate()
		visuals_container.add_child(new_model)
		
		# Apply Scale to the CONTAINER, not the mesh
		visuals_container.scale = Vector3.ONE * stats.scale
		
		# Find Animation Player
		var anim = find_animation_player(new_model)
		if anim:
			anim_player = anim

# Helper function to find the animation player in the imported scene
func find_animation_player(root_node: Node) -> AnimationPlayer:
	for child in root_node.get_children():
		if child is AnimationPlayer:
			return child
		# Recursive search in case it's buried deep
		var found = find_animation_player(child)
		if found: return found
	return null
# --- MAIN PHYSICS LOOP ---
func _physics_process(delta):
	# Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Update Attack Cooldown Timer
	if attack_timer > 0:
		attack_timer -= delta

	# State Machine Logic
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DEAD, State.RESPAWNING:
			pass # Do nothing
	_update_animation_state()
	move_and_slide()

# --- STATE FUNCTIONS ---

func _process_idle(_delta):
	# Slow down to a stop
	velocity.x = move_toward(velocity.x, 0, 1.0)
	velocity.z = move_toward(velocity.z, 0, 1.0)
	
	# Transition: If we have a target, start chasing
	if player_target:
		current_state = State.CHASE

func _process_chase(_delta):
	if not player_target or not movement_component:
		current_state = State.IDLE
		return

	# 1. Get Distance
	var distance = global_position.distance_to(player_target.global_position)
	
	# 2. Move using Component
	var chase_velocity = movement_component.get_chase_velocity()
	velocity.x = chase_velocity.x
	velocity.z = chase_velocity.z
	movement_component.look_at_target()

	# 3. Transition: Attack if close enough
	# Use the stats.attack_range for the check
	var range_check = stats.attack_range if stats else 1.5
	if distance <= range_check:
		current_state = State.ATTACK

func _process_attack(_delta):
	# Stop moving while attacking
	velocity.x = move_toward(velocity.x, 0, 1.0)
	velocity.z = move_toward(velocity.z, 0, 1.0)
	
	if not player_target:
		current_state = State.IDLE
		return

	# Face the player even while attacking
	if movement_component:
		movement_component.look_at_target()
	# Try to Attack
	if attack_timer <= 0:
		if combat_component:
			combat_component.try_attack() 
			
			# --- NEW: Trigger Attack Animation ---
			if anim_player and anim_player.has_animation("Attack"):
				anim_player.stop() # Stop running/idle immediately
				anim_player.play("Attack", 0.1)
				
			attack_timer = stats.attack_rate if stats else 1.0
	# Try to Attack (Managed by our local timer + Component check)
	if attack_timer <= 0:
		if combat_component:
			combat_component.try_attack() 
			# Reset local timer based on stats
			attack_timer = stats.attack_rate if stats else 1.5

	# Transition: Go back to chase if player runs away
	var distance = global_position.distance_to(player_target.global_position)
	var range_check = stats.attack_range if stats else 1.5
	
	# Add buffer (0.5) to prevent jittering
	if distance > range_check + 0.5: 
		current_state = State.CHASE

# --- HELPER FUNCTIONS ---

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_target = players[0]
		# Update components with the target
		if movement_component: movement_component.set_target(player_target)
		if combat_component: combat_component.set_target(player_target)
		
		if current_state == State.IDLE:
			current_state = State.CHASE

func take_damage(amount: float): # Updated to float to match component
	if health_component:
		health_component.take_damage(amount)

# --- SIGNALS & VISUALS (Your original Tweens) ---

func _on_attack_visuals():
	# Move the whole container
	var tween = create_tween()
	tween.tween_property(visuals_container, "position", Vector3(0, 0, -0.5), 0.1).as_relative()
	tween.tween_property(visuals_container, "position", Vector3(0, 0, 0.5), 0.2).as_relative()

func _on_hit(_amount):
	_update_ui(health_component.current_health, health_component.max_health)
	
	# Scale the whole container
	var tween = create_tween()
	tween.tween_property(visuals_container, "scale", Vector3(1.1, 0.9, 1.1), 0.1)
	tween.tween_property(visuals_container, "scale", Vector3.ONE * (stats.scale if stats else 1.0), 0.1)

# --- ANIMATION LOGIC ---
func _update_animation_state():
	# If no model is loaded or no animation player found, skip
	if not anim_player: 
		return

	# We use a simple match to decide which loop to play
	match current_state:
		State.IDLE:
			play_anim_safe("Idle")
		State.CHASE:
			# You can rename "Run" to "Walk" if your assets use that name
			play_anim_safe("Run") 
		State.DEAD:
			play_anim_safe("Death")

# Helper to prevent crashes if an animation is missing
# e.g. If you load a Spider that has "Walk" but not "Run", this prevents an error
func play_anim_safe(anim_name: String):
	if anim_player.has_animation(anim_name):
		# 0.2s blend time makes transitions smooth (no popping)
		anim_player.play(anim_name, 0.2)

func _update_ui(current, max_hp):
	if health_bar:
		health_bar.update_bar(current, max_hp)

func _on_death():
	current_state = State.DEAD
	SignalBus.enemy_died.emit(self)
	
	velocity = Vector3.ZERO
	visuals_container.visible = false
	collision_shape.set_deferred("disabled", true)
	
	if auto_respawn:
		current_state = State.RESPAWNING
		await get_tree().create_timer(respawn_time).timeout
		respawn()
	else:
		queue_free()

func respawn():
	health_component.reset_health()
	visuals_container.visible = true
	# Reset scale based on stats
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
