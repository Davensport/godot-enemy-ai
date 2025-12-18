extends Node3D

@onready var label = $Label3D
@onready var ready_icon = $ReadyIcon 

# --- VOICE REFERENCE (NEW) ---
# Ensure you have a Label3D named "VoiceLabel" or change this name
@onready var voice_label = $VoiceLabel 
@onready var voice_component = $VoiceComponent

# --- MESH REFERENCES ---
@onready var body_mesh = $"Mesh/Root Scene/RootNode/CharacterArmature/Skeleton3D/Rogue"
@onready var hair_mesh = $"Mesh/Root Scene/RootNode/CharacterArmature/Skeleton3D/Head/NurbsPath_001"

# ==============================================================================
# CONFIGURATION
# ==============================================================================
const VISUAL_CONFIG = {
	"Tunic": { "surface": 3, "target": "body" }, 
	"Skin":  { "surface": 0, "target": "body" },
	"Hair":  { "surface": 0, "target": "hair" } 
}

var player_data = {
	"Tunic": null,
	"Skin": null,
	"Hair": null
}

@export var player_color := Color.WHITE

# SETTER: When LobbyManager changes this, the Text updates automatically
@export var player_name := "":
	set(value):
		player_name = value
		if label: label.text = value

func _ready():
	# 1. VISUAL SETUP
	if label: label.text = player_name
	if ready_icon: ready_icon.visible = false
	if voice_label: voice_label.visible = false
	
	_apply_visuals()

	# 2. VOICE CONNECTION (This makes the speaker icon work!)
	if voice_component:
		# Connect the signal from VoiceComponent to our local function
		voice_component.on_talking.connect(_on_player_talking)

	# --- DELETED "Input Logic" ---
	# We removed the name setting logic here because LobbyWaitingRoom.gd 
	# handles it better for everyone.

func _on_player_talking(is_talking: bool):
	if voice_label:
		voice_label.visible = is_talking

# ==============================================================================
# VISUAL LOGIC
# ==============================================================================

func apply_customization_data(new_data: Dictionary):
	for key in new_data:
		player_data[key] = new_data[key]
	_apply_visuals()

func _apply_visuals():
	for part_name in player_data:
		if part_name in VISUAL_CONFIG:
			var config = VISUAL_CONFIG[part_name]
			var color = player_data[part_name]
			
			var target_mesh = null
			if config["target"] == "body":
				target_mesh = body_mesh
			elif config["target"] == "hair":
				target_mesh = hair_mesh
			
			if target_mesh:
				var surface_index = config["surface"]
				if color == null:
					target_mesh.set_surface_override_material(surface_index, null)
				else:
					var mat = StandardMaterial3D.new()
					mat.albedo_color = color
					target_mesh.set_surface_override_material(surface_index, mat)

func set_ready_visuals(is_ready: bool):
	if ready_icon: ready_icon.visible = is_ready
	if label: label.modulate = Color.GREEN if is_ready else Color.WHITE

# ==============================================================================
# RPCs
# ==============================================================================
# Kept for compatibility, but LobbyManager should be handling names now.
@rpc("any_peer", "call_remote", "reliable")
func set_name_on_server(new_name):
	if multiplayer.is_server():
		player_name = new_name

@rpc("any_peer", "call_remote", "reliable")
func set_color_on_server(_new_color):
	pass
