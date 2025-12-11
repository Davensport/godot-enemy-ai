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

# --- VISUALS ---
@onready var character_mesh = $RootNode/CharacterArmature/Skeleton3D/Rogue
@onready var hair_mesh = $RootNode/CharacterArmature/Skeleton3D/Head/NurbsPath_001

# --- CONFIG ---
@export var hud_scene: PackedScene 

# --- STATE ---
var is_flying: bool = false
var _saved_collision_mask: int = 1
var _current_visual_color: Color = Color.WHITE 

# --- LOBBY COMPATIBILITY ---
var player_name: String = ""

# --- NETWORK VARIABLES ---
@export var player_color: Color = Color.WHITE

# 1. NETWORK SETTER (The Shout)
@rpc("any_peer", "call_local")
func set_color_on_server(new_color):
	player_color = new_color
	# We manually trigger the paint here to ensure the RPC works
	_apply_color_to_mesh(new_color)

# 2. THE PAINTER
func _apply_color_to_mesh(color):
	if not is_node_ready(): await ready
	
	_current_visual_color = color
	
	# Paint Body
	if character_mesh:
		var mat = character_mesh.get_active_material(0)
		if mat:
			if mat.albedo_color != color:
				mat = mat.duplicate()
				mat.albedo_color = color
				character_mesh.set_surface_override_material(0, mat)
		else:
			var new_mat = StandardMaterial3D.new()
			new_mat.albedo_color = color
			character_mesh.material_override = new_mat

	# Paint Hair
	if hair_mesh:
		var hair_mat = hair_mesh.get_active_material(0)
		if hair_mat:
			if hair_mat.albedo_color != color:
				hair_mat = hair_mat.duplicate()
				hair_mat.albedo_color = color
				hair_mesh.set_surface_override_material(0, hair_mat)

# --- LIFECYCLE ---

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	await get_tree().process_frame
	
	if is_multiplayer_authority():
		# --- I AM THE PLAYER (LOCAL) ---
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera_rig.current = true
		
		# 1. GET MY COLOR (From Lobby)
		var my_id = multiplayer.get_unique_id()
		var my_color = Color.WHITE
		if Global.player_colors.has(my_id):
			my_color = Global.player_colors[my_id]
		
		# 2. APPLY LOCALLY
		_apply_color_to_mesh(my_color)
		
		# 3. FORCE SEND TO SERVER (The Fix)
		# We command the server to update our variable
		set_color_on_server.rpc(my_color)
		
		# Visual Fixes (Hide self)
		if character_mesh:
			character_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if hair_mesh:
			hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		
		# Spawn HUD
		if hud_scene:
			var hud = hud_scene.instantiate()
			add_child(hud)
			if hud.has_method("setup_ui"):
				hud.setup_ui(self)
				
	else:
		# --- I AM A PUPPET ---
		camera_rig.current = false
		set_physics_process(false)
		set_process(true)
		
		# Ensure visible
		if character_mesh:
			character_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if hair_mesh:
			hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		
		# Apply whatever color the variable currently holds (Sync catch-up)
		_apply_color_to_mesh(player_color)

	if health:
		health.on_death.connect(_on_death_logic)

# --- PROCESS LOOP (Watchdog) ---

func _process(delta):
	# Watchdog: If network updates the variable, force the mesh to match
	if player_color != _current_visual_color:
		_apply_color_to_mesh(player_color)

	if not is_multiplayer_authority():
		_update_puppet_animations()

func _update_puppet_animations():
	var current_speed = velocity.length()
	var playback = AnimTree.get("parameters/Motion/playback")
	if playback:
		if current_speed > 0.1:
			playback.travel("Run")
		else:
			playback.travel("Idle")

# --- PHYSICS ---

func _input(event):
	if not is_multiplayer_authority(): return
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
	if is_flying:
		# Simple fly
		var dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var cam_basis = camera_rig.global_basis
		var target_vel = (cam_basis * Vector3(dir.x, 0, dir.y)).normalized() * 20.0
		if Input.is_action_pressed("jump"): target_vel += Vector3.UP * 10.0
		if Input.is_action_pressed("crouch"): target_vel += Vector3.DOWN * 10.0
		velocity = velocity.lerp(target_vel, 10.0 * delta)
	else:
		movement.handle_movement(delta)
	move_and_slide()

# --- DEATH ---

func take_damage(amount):
	if multiplayer.is_server():
		health.take_damage(amount)

func _on_death_logic():
	on_player_died.emit()
	set_physics_process(false)
	AnimTree["parameters/LifeState/transition_request"] = "dead"
	AnimPlayer.stop()
	SignalBus.player_died.emit()
