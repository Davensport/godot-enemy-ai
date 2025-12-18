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

# --- VISUALS (Renamed 'character_mesh' to 'body_mesh' for consistency) ---
@onready var body_mesh = $RootNode/CharacterArmature/Skeleton3D/Rogue
@onready var hair_mesh = $RootNode/CharacterArmature/Skeleton3D/Head/NurbsPath_001

# --- CONFIG ---
@export var hud_scene: PackedScene 

# --- VISUAL CONFIGURATION (Matches Lobby) ---
const VISUAL_CONFIG = {
	"Tunic": { "surface": 3, "target": "body" }, 
	"Skin":  { "surface": 0, "target": "body" },
	"Hair":  { "surface": 0, "target": "hair" } 
}

# --- STATE ---
var is_flying: bool = false
var _saved_collision_mask: int = 1
var _saved_collision_layer: int = 1 
var player_name: String = ""

# Store visual data (Null = Original Mesh)
var visual_data = {
	"Tunic": null,
	"Skin": null,
	"Hair": null
}

# --- NETWORK VARIABLES ---
# Legacy variable (Kept for safety, but setter removed so it doesn't overwrite)
@export var player_color: Color = Color.WHITE

@rpc("any_peer", "call_local")
func set_color_on_server(_color):
	pass # Dead end function

# --- PAINTER (THE NEW SYSTEM) ---
func apply_customization_data(new_data: Dictionary):
	# Update local dictionary
	for key in new_data:
		visual_data[key] = new_data[key]
	
	# Only paint if we are already in the scene tree
	if is_node_ready():
		_apply_visuals()

func _apply_visuals():
	for part_name in visual_data:
		if part_name in VISUAL_CONFIG:
			var config = VISUAL_CONFIG[part_name]
			var color = visual_data[part_name]
			
			# 1. FIND TARGET MESH
			var target_mesh = null
			if config["target"] == "body":
				target_mesh = body_mesh
			elif config["target"] == "hair":
				target_mesh = hair_mesh
			
			# 2. APPLY PAINT
			if target_mesh:
				var surface_index = config["surface"]
				if color == null:
					target_mesh.set_surface_override_material(surface_index, null)
				else:
					var mat = StandardMaterial3D.new()
					mat.albedo_color = color
					target_mesh.set_surface_override_material(surface_index, mat)

# --- LIFECYCLE ---

func _enter_tree():
	var my_id = str(name).to_int()
	set_multiplayer_authority(my_id)
	
	for child in $Components.get_children():
		child.set_multiplayer_authority(my_id)

func _ready():
	await get_tree().process_frame
	
	_saved_collision_mask = collision_mask
	_saved_collision_layer = collision_layer
	
	var this_player_id = str(name).to_int()
	
	# 1. LOAD CUSTOMIZATION FROM GLOBAL
	if Global.player_customization.has(this_player_id):
		apply_customization_data(Global.player_customization[this_player_id])
	elif Global.player_colors.has(this_player_id):
		# Fallback for old system
		apply_customization_data({"Tunic": Global.player_colors[this_player_id]})
	
	# Force apply visuals now that we are ready
	_apply_visuals()
	
	if is_multiplayer_authority():
		# --- LOCAL PLAYER ---
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera_rig.current = true
		
		# Shadow settings
		if body_mesh:
			body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if hair_mesh:
			hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		
		# UI SETUP
		if hud_scene:
			var hud = hud_scene.instantiate()
			add_child(hud)
			if hud.has_method("setup_ui"):
				hud.setup_ui(self)
		
		SignalBus.respawn_requested.connect(_on_ui_respawn_requested)
				
	else:
		# --- PUPPET ---
		camera_rig.current = false
		set_physics_process(false)
		set_process(true)
		
		if body_mesh:
			body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if hair_mesh:
			hair_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		
		# Ensure puppets are painted too
		_apply_visuals()

	if health and multiplayer.is_server():
		health.on_death.connect(_on_death_logic)

# --- PROCESS LOOP ---

func _process(_delta):
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

# --- DAMAGE AND DEATH ---

func take_damage(amount):
	if multiplayer.is_server():
		health.take_damage(amount)
		_rpc_update_health.rpc(health.current_health, health.max_health)

@rpc("any_peer", "call_local", "reliable")
func _rpc_update_health(new_health, new_max):
	if multiplayer.get_remote_sender_id() != 1: return
	if health:
		health.current_health = new_health
		health.max_health = new_max
		health.on_health_changed.emit(new_health, new_max)

func _on_death_logic():
	if multiplayer.is_server():
		_rpc_player_died.rpc()

@rpc("any_peer", "call_local", "reliable")
func _rpc_player_died():
	if multiplayer.get_remote_sender_id() != 1: return

	on_player_died.emit()
	set_physics_process(false)
	velocity = Vector3.ZERO
	collision_layer = 0
	
	AnimTree["parameters/LifeState/transition_request"] = "dead"
	AnimPlayer.stop()
	
	if is_multiplayer_authority():
		SignalBus.player_died.emit()

	await get_tree().create_timer(2.0).timeout
	
	if health.current_health > 0: return
		
	if body_mesh: body_mesh.visible = false
	if hair_mesh: hair_mesh.visible = false

# --- RESPAWN LOGIC ---

func _on_ui_respawn_requested():
	_rpc_request_respawn.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _rpc_request_respawn():
	if not multiplayer.is_server(): return
	
	if health:
		health.reset_health() 
		_rpc_update_health.rpc(health.current_health, health.max_health)
	
	var random_offset = Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
	var spawn_pos = Vector3(0, 2, 0) + random_offset
	
	_rpc_perform_respawn.rpc(spawn_pos)

@rpc("any_peer", "call_local", "reliable")
func _rpc_perform_respawn(spawn_pos: Vector3):
	if multiplayer.get_remote_sender_id() != 1: return

	if body_mesh: body_mesh.visible = true
	if hair_mesh: hair_mesh.visible = true

	global_position = spawn_pos
	velocity = Vector3.ZERO
	set_physics_process(true)
	collision_layer = _saved_collision_layer
	
	AnimTree["parameters/LifeState/transition_request"] = "state_0"
	AnimPlayer.play("Idle")
	
	if is_multiplayer_authority():
		camera_rig.current = true
