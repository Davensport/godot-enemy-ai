class_name PlayerController
extends CharacterBody3D

signal on_player_died

# --- COMPONENTS ---
@onready var movement = $Components/Movement
@onready var combat = $Components/Combat
@onready var camera_rig = $Head/Camera3D
@onready var health = $Components/HealthComponent
@onready var AnimPlayer = $AnimationPlayer
@onready var AnimTree = $AnimationTree

# --- VISUALS (The Fix) ---
# We grab the specific mesh node using the path you provided
@onready var character_mesh = $RootNode/CharacterArmature/Skeleton3D/Rogue
@onready var hair_mesh = $RootNode/CharacterArmature/Skeleton3D/Head/NurbsPath_001

# --- CONFIG ---
@export var hud_scene: PackedScene 

# --- STATE ---
var is_flying: bool = false
var _saved_collision_mask: int = 1

# --- LOBBY COMPATIBILITY ---
var player_name: String = ""
var player_color: Color = Color.WHITE

func set_color_on_server(color):
	player_color = color
	# Optional: If you want to change the outfit color later, do it here.

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	# Wait one frame to ensure Godot has finished network setup
	await get_tree().process_frame
	
	if is_multiplayer_authority():
		# --- I AM THE PLAYER (LOCAL) ---
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera_rig.current = true
		
		# 1. VISUAL FIX: Hide body from my own camera, but KEEP SHADOWS
		if character_mesh:
			character_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			
		# 2. VISUAL FIX: Hide HAIR from camera (New!)
		if hair_mesh:
			hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		
		# 2. SPAWN HUD
		if hud_scene:
			var hud = hud_scene.instantiate()
			add_child(hud)
			if hud.has_method("setup_ui"):
				hud.setup_ui(self)
				
	else:
		# --- I AM A PUPPET (OTHER PLAYER) ---
		camera_rig.current = false
		set_physics_process(false)
		set_process(true) # Keep animating!
		
		# Ensure mesh is fully visible for others
		if character_mesh:
			character_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if hair_mesh:
			hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	if health:
		health.on_death.connect(_on_death_logic)

func _input(event):
	# [MULTIPLAYER] Guard rail
	if not is_multiplayer_authority(): return

	# Fly Mode (Debug/Cheat)
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		is_flying = !is_flying
		if is_flying:
			motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
			_saved_collision_mask = collision_mask
			collision_mask = 0 
		else:
			motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
			collision_mask = _saved_collision_mask

func _physics_process(delta):
	# Only run physics for the local player
	if is_flying:
		var dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var cam_basis = camera_rig.global_basis
		var target_vel = (cam_basis * Vector3(dir.x, 0, dir.y)).normalized() * 20.0
		if Input.is_action_pressed("jump"): target_vel += Vector3.UP * 10.0
		if Input.is_action_pressed("crouch"): target_vel += Vector3.DOWN * 10.0
		velocity = velocity.lerp(target_vel, 10.0 * delta)
	else:
		movement.handle_movement(delta)
	
	move_and_slide()

func _process(delta):
	# Update animations for other players
	if not is_multiplayer_authority():
		_update_puppet_animations()

func _update_puppet_animations():
	var current_speed = velocity.length()
	# Check your AnimationTree paths! 
	# Standard is "parameters/Motion/playback" or "parameters/playback"
	var playback = AnimTree.get("parameters/Motion/playback")
	
	if playback:
		if current_speed > 1.0:
			playback.travel("Run")
		else:
			playback.travel("Idle")

func take_damage(amount):
	if multiplayer.is_server():
		health.take_damage(amount)

func _on_death_logic():
	on_player_died.emit()
	
	# Stop physics
	set_physics_process(false)
	
	# Play death animation
	AnimTree["parameters/LifeState/transition_request"] = "dead"
	AnimPlayer.stop()
	
	# Trigger HUD Button
	SignalBus.player_died.emit() 
	
	# DO NOT queue_free() here! Wait for the Respawn button.
