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
	var my_id = str(name).to_int()
	set_multiplayer_authority(my_id)
	
	for child in $Components.get_children():
		child.set_multiplayer_authority(my_id)

func _ready():
	await get_tree().process_frame
	
	var this_player_id = str(name).to_int()
	
	# 1. Try to find the color in the Global Lobby List
	if Global.player_colors.has(this_player_id):
		player_color = Global.player_colors[this_player_id]
		_apply_color_to_mesh(player_color)
	
	# 2. Backup: Client tells Server their color
	if is_multiplayer_authority():
		set_color_on_server.rpc(player_color)
	
	if is_multiplayer_authority():
		# --- I AM THE PLAYER (LOCAL) ---
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera_rig.current = true
		
		# Hide self geometry (optional)
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
		
		if character_mesh:
			character_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if hair_mesh:
			hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		
		_apply_color_to_mesh(player_color)

	# LISTEN FOR DEATH (Server Side)
	if health:
		health.on_death.connect(_on_death_logic)

# --- PROCESS LOOP ---

func _process(_delta):
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

# --- DAMAGE AND DEATH (NETWORKED) ---

# 1. Enemy calls this on the SERVER
func take_damage(amount):
	if multiplayer.is_server():
		# Apply damage to the server component
		health.take_damage(amount)
		
		# FORCE SYNC: Tell the clients what the new health is so their UI updates
		# Note: We assume your health component has 'current_health' and 'max_health'
		_rpc_update_health.rpc(health.current_health, health.max_health)

# 2. All Clients receive this
@rpc("call_local", "reliable")
func _rpc_update_health(new_health, new_max):
	if health:
		# Update local variables
		health.current_health = new_health
		health.max_health = new_max
		
		# Force the "on_health_changed" signal so the HUD updates
		health.on_health_changed.emit(new_health, new_max)

# 3. Server detects death -> Tells everyone to play animation
func _on_death_logic():
	if multiplayer.is_server():
		_rpc_player_died.rpc()

# 4. Everyone executes death logic
@rpc("call_local", "reliable")
func _rpc_player_died():
	on_player_died.emit()
	set_physics_process(false)
	
	# Play Animation
	AnimTree["parameters/LifeState/transition_request"] = "dead"
	AnimPlayer.stop() # Sometimes helps transition trigger cleanly
	
	# Only emit global signal if local player (optional, prevents double signals)
	if is_multiplayer_authority():
		SignalBus.player_died.emit()
