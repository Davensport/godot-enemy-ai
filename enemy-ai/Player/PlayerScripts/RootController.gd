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

var player_name: String = ""

# --- NETWORK VARIABLES ---
# We keep the RPC logic just in case, but the Global check is the main fix.
@export var player_color: Color = Color.WHITE:
	set(new_color):
		player_color = new_color
		_apply_color_to_mesh(new_color)

@rpc("any_peer", "call_local")
func set_color_on_server(color):
	player_color = color
	_apply_color_to_mesh(color)

# --- PAINTER ---
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
	
	# --- THE FIX: GLOBAL LOOKUP FOR EVERYONE ---
	# We do this for ALL players, not just our own.
	# "Who is this player? Let's check the list."
	var this_player_id = str(name).to_int()
	
	# 1. Try to find the color in the Global Lobby List
	if Global.player_colors.has(this_player_id):
		player_color = Global.player_colors[this_player_id]
		_apply_color_to_mesh(player_color)
	
	# 2. If I am the Client owner, ensure the Server knows my color too (Backup)
	if is_multiplayer_authority():
		set_color_on_server.rpc(player_color)
	# -------------------------------------------
	
	if is_multiplayer_authority():
		# --- I AM THE PLAYER (LOCAL) ---
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera_rig.current = true
		
		# Hide self
		if character_mesh:
			character_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if hair_mesh:
			hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		
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
		
		# Just in case the Global check failed, apply whatever variable we have
		_apply_color_to_mesh(player_color)

	if health:
		health.on_death.connect(_on_death_logic)

# --- PROCESS LOOP ---

func _process(delta):
	# Watchdog: If RPC comes in later, update the mesh
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
