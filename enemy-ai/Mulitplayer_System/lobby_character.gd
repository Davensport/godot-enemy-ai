extends Node3D

@onready var label = $Label3D
# Keep your mesh path!
@onready var mesh = $"Mesh/Root Scene/RootNode/CharacterArmature/Skeleton3D/Rogue"

@export var player_name := "":
	set(value):
		player_name = value
		if label: label.text = value

@export var player_color := Color.WHITE:
	set(new_color):
		player_color = new_color
		_update_color()

func _enter_tree():
	set_multiplayer_authority(1)

func _ready():
	if label: label.text = player_name
	_update_color()
	
	# --- FIX START ---
	# If I am the human owner of this mannequin...
	if name.to_int() == multiplayer.get_unique_id():
		var my_name = Steam.getPersonaName()
		
		if multiplayer.is_server():
			# I AM THE HOST: Just run the function directly. No RPC needed.
			set_name_on_server(my_name)
		else:
			# I AM A CLIENT: Send a packet to the Host (ID 1).
			set_name_on_server.rpc_id(1, my_name)
	# --- FIX END ---

func _update_color():
	if mesh:
		if player_color == Color.WHITE:
			mesh.set_surface_override_material(0, null)
		else:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = player_color
			mesh.set_surface_override_material(0, mat)

@rpc("any_peer", "call_remote", "reliable")
func set_name_on_server(new_name):
	if multiplayer.is_server():
		player_name = new_name

@rpc("any_peer", "call_remote", "reliable")
func set_color_on_server(new_color):
	if multiplayer.is_server():
		player_color = new_color
		var id = name.to_int()
		Global.player_colors[id] = new_color
