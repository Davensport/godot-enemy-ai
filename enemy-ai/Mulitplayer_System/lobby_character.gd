extends Node3D

@onready var label = $Label3D
@onready var ready_icon = $ReadyIcon 

# --- MESH REFERENCES ---
# 1. The Main Body
@onready var body_mesh = $"Mesh/Root Scene/RootNode/CharacterArmature/Skeleton3D/Rogue"
# 2. The Hair
@onready var hair_mesh = $"Mesh/Root Scene/RootNode/CharacterArmature/Skeleton3D/Head/NurbsPath_001"

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# Map the part name to:
#  - "surface": Which material slot number to paint
#  - "target": "body" or "hair" to know which mesh to use
const VISUAL_CONFIG = {
	"Tunic": { "surface": 3, "target": "body" }, 
	"Skin":  { "surface": 0, "target": "body" },
	"Hair":  { "surface": 0, "target": "hair" } 
}

# Default Data (NULL means "Use Original Mesh Material")
var player_data = {
	"Tunic": null,
	"Skin": null,
	"Hair": null
}

# Legacy support for old scripts that might try to set 'player_color'
@export var player_color := Color.WHITE:
	set(new_color):
		player_color = new_color
		apply_customization_data({"Tunic": new_color})

@export var player_name := "":
	set(value):
		player_name = value
		if label: label.text = value

func _enter_tree():
	set_multiplayer_authority(1)

func _ready():
	if label: label.text = player_name
	if ready_icon: ready_icon.visible = false
	
	_apply_visuals()
	
	# Sync Steam Name
	if name.to_int() == multiplayer.get_unique_id():
		var my_name = Steam.getPersonaName()
		if multiplayer.is_server():
			set_name_on_server(my_name)
		else:
			set_name_on_server.rpc_id(1, my_name)

# ==============================================================================
# VISUAL LOGIC
# ==============================================================================

func apply_customization_data(new_data: Dictionary):
	# Merge new data so we don't lose other parts
	for key in new_data:
		player_data[key] = new_data[key]
	_apply_visuals()

func _apply_visuals():
	# Loop through our data (Tunic, Skin, Hair)
	for part_name in player_data:
		
		# Do we have a config for this part?
		if part_name in VISUAL_CONFIG:
			var config = VISUAL_CONFIG[part_name]
			var color = player_data[part_name]
			
			# 1. DECIDE WHICH MESH TO PAINT
			var target_mesh = null
			if config["target"] == "body":
				target_mesh = body_mesh
			elif config["target"] == "hair":
				target_mesh = hair_mesh
			
			# 2. PAINT IT (Safely)
			if target_mesh:
				var surface_index = config["surface"]
				
				if color == null:
					# RESET: Reveal the original imported texture
					target_mesh.set_surface_override_material(surface_index, null)
				else:
					# PAINT: Apply the chosen color
					var mat = StandardMaterial3D.new()
					mat.albedo_color = color
					target_mesh.set_surface_override_material(surface_index, mat)

func set_ready_visuals(is_ready: bool):
	if ready_icon: ready_icon.visible = is_ready
	if label: label.modulate = Color.GREEN if is_ready else Color.WHITE

# ==============================================================================
# RPCs
# ==============================================================================
@rpc("any_peer", "call_remote", "reliable")
func set_name_on_server(new_name):
	if multiplayer.is_server():
		player_name = new_name

@rpc("any_peer", "call_remote", "reliable")
func set_color_on_server(new_color):
	if multiplayer.is_server():
		player_color = new_color
		var id = name.to_int()
		Global.update_customization("Tunic", new_color)
