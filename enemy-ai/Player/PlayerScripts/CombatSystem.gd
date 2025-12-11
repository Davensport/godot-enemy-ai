class_name CombatComponent
extends Node

signal on_damage_multiplier_changed(new_mult: float)

@export var damage_multiplier: float = 1.0:
	set(value):
		damage_multiplier = value
		on_damage_multiplier_changed.emit(damage_multiplier)

@export_group("Settings")
@export var buffer_window: float = 0.2 # How long to remember a button press
@export var fireball_cooldown: float = 0.6 

@export_group("References")
@export var animation_tree: AnimationTree
@export var input: InputComponent
@export var projectile_spawn_point: Node3D
@export var projectile_scene: PackedScene 
@export var camera: Camera3D 

# Ensure this path matches where your sword is in the Scene Tree!
@onready var sword_scene = $"../../RootNode/CharacterArmature/Skeleton3D/WeaponSocket_Normal/Sword"

var can_fireball: bool = true 
var _buffer_timer: float = 0.0
var _queued_action: Callable = Callable()

func _ready():
	# We connect signals to the BUFFER functions
	input.on_attack_sword.connect(buffer_sword_attack)
	input.on_attack_fireball.connect(buffer_fireball_attack)
	
	call_deferred("emit_signal", "on_damage_multiplier_changed", damage_multiplier)

func _process(delta: float):
	# 1. Manage Buffer Timer
	if _buffer_timer > 0:
		_buffer_timer -= delta
		
		# 2. Try to Execute Buffered Action
		if not is_animation_busy():
			if _queued_action.is_valid():
				_queued_action.call()
			_buffer_timer = 0.0 

# --- HELPER: The Core of the Logic ---
func is_animation_busy() -> bool:
	return animation_tree.get("parameters/AttackShot/active")

# --- BUFFERING INPUTS ---
func buffer_sword_attack():
	_buffer_timer = buffer_window
	_queued_action = perform_sword_attack

func buffer_fireball_attack():
	_buffer_timer = buffer_window
	_queued_action = perform_fireball

# --- EXECUTION (RPC UPDATED) ---

func perform_sword_attack():
	# Step 1: Tell the network to attack
	# "call_local" ensures it runs on YOUR screen immediately too
	execute_sword_attack.rpc()

@rpc("call_local", "reliable")
func execute_sword_attack():
	# Step 2: The actual logic that runs on every computer
	
	# Safety check
	if sword_scene.currently_attacking: return

	# Play Animation
	animation_tree.set("parameters/AttackType/transition_request", "state_0")
	animation_tree.set("parameters/AttackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	# Activate Hitbox
	sword_scene.attack()
		
func perform_fireball():
	if not can_fireball: return
	# Tell network to fire
	execute_fireball_attack.rpc()

@rpc("call_local", "reliable")
func execute_fireball_attack():
	can_fireball = false
	
	animation_tree.set("parameters/AttackType/transition_request", "state_1")
	animation_tree.set("parameters/AttackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	if projectile_scene:
		var fireball = projectile_scene.instantiate()
		get_tree().root.add_child(fireball)
		fireball.global_position = projectile_spawn_point.global_position
		
		# Visual rotation match
		if camera:
			fireball.global_rotation = camera.global_rotation
		else:
			fireball.global_rotation = projectile_spawn_point.global_rotation

	# Visual Cooldown
	await get_tree().create_timer(fireball_cooldown).timeout
	can_fireball = true
