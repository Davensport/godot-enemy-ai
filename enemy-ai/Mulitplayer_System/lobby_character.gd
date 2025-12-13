extends Node3D

@onready var label = $Label3D
@onready var ready_icon = $ReadyIcon 

# --- MESH REFERENCES ---
@onready var body_mesh = $"Mesh/Root Scene/RootNode/CharacterArmature/Skeleton3D/Rogue"
# Update this path if it is incorrect for your project!
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

# --- THE FIX IS HERE ---
# We removed the 'set(new_color)' block. 
# Now, this variable is just data. It won't overwrite your visuals.
@export var player_color := Color.WHITE

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
func set_color_on_server(_new_color):
	# We leave this empty or redirect it, but we don't want it forcing 'player_color' logic
	pass
