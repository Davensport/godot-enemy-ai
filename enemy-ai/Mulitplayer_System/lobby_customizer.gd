extends Control

# --- UI REFERENCES ---
@onready var part_label = $PanelContainer/VBoxContainer/HBoxContainer/PartLabel
@onready var color_display = $PanelContainer/VBoxContainer/HBoxContainer2/ColorDisplay

# --- DATA CONFIGURATION ---
var body_parts = ["Tunic", "Skin", "Hair"]
var current_part_index = 0

# Define specific palettes for each part (Optional polish!)
var palettes = {
	"Tunic": [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.WHITE, Color.BLACK, Color.PURPLE],
	"Skin": [Color("ffcc99"), Color("e0ac69"), Color("8d5524"), Color("523218"), Color("ffdbac")],
	"Hair": [Color.BROWN, Color.BLACK, Color.WEB_GRAY, Color.GOLD, Color.ORANGE_RED]
}
var current_color_index = 0

# --- TARGETING ---
var target_player_node: Node3D = null # The 3D character we are following
var main_camera: Camera3D = null

func _ready():
	_update_ui()

func _process(_delta):
	# FLOATING LOGIC: Snap this UI to the 3D player's feet
	if target_player_node and main_camera:
		# Find where the feet are in the 3D world
		var feet_pos = target_player_node.global_position 
		feet_pos.y -= 0.5 # Offset slightly down
		
		# Convert 3D world position to 2D screen coordinate
		var screen_pos = main_camera.unproject_position(feet_pos)
		
		# Center the panel on that point
		# (Assuming PanelContainer is the first child)
		var panel_size = $PanelContainer.size
		global_position = screen_pos - Vector2(panel_size.x / 2, 0)

# --- PART BUTTONS ---
func _on_left_part_btn_pressed():
	current_part_index -= 1
	if current_part_index < 0: current_part_index = body_parts.size() - 1
	current_color_index = 0 # Reset color index when switching parts
	_update_ui()

func _on_right_part_btn_pressed():
	current_part_index += 1
	if current_part_index >= body_parts.size(): current_part_index = 0
	current_color_index = 0
	_update_ui()

# --- COLOR BUTTONS ---
func _on_left_color_btn_pressed():
	var part_name = body_parts[current_part_index]
	var palette = palettes.get(part_name, palettes["Tunic"]) # Default to tunic colors if missing
	
	current_color_index -= 1
	if current_color_index < 0: current_color_index = palette.size() - 1
	_apply_change()

func _on_right_color_btn_pressed():
	var part_name = body_parts[current_part_index]
	var palette = palettes.get(part_name, palettes["Tunic"])
	
	current_color_index += 1
	if current_color_index >= palette.size(): current_color_index = 0
	_apply_change()

# --- HELPERS ---
func _update_ui():
	var part_name = body_parts[current_part_index]
	part_label.text = part_name
	
	# Update color display to show current selection
	var palette = palettes.get(part_name, palettes["Tunic"])
	# Safety check for empty palettes
	if palette.size() > 0:
		color_display.color = palette[current_color_index]

func _apply_change():
	var part_name = body_parts[current_part_index]
	var palette = palettes.get(part_name, palettes["Tunic"])
	var selected_color = palette[current_color_index]
	
	# Update UI Visual
	color_display.color = selected_color
	
	# SEND TO SERVER (Using the code we wrote previously)
	Global.update_customization(part_name, selected_color)
