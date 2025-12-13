extends Control

# --- UI REFERENCES ---
@onready var part_label = $PanelContainer/VBoxContainer/HBoxContainer/PartLabel
@onready var color_display = $PanelContainer/VBoxContainer/HBoxContainer2/ColorDisplay

# --- SETTINGS ---
# Use this to nudge the UI exactly where you want it.
# (X, Y) -> Positive X moves Right, Positive Y moves Down
@export var ui_offset: Vector2 = Vector2(0, 0) 

# --- DATA CONFIGURATION ---
var body_parts = ["Tunic", "Skin", "Hair"]
var current_part_index = 0

var palettes = {
	"Tunic": [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW, Color.WHITE, Color.BLACK, Color.PURPLE],
	"Skin": [Color("ffcc99"), Color("e0ac69"), Color("8d5524"), Color("523218"), Color("ffdbac")],
	"Hair": [Color.BROWN, Color.BLACK, Color.WEB_GRAY, Color.GOLD, Color.ORANGE_RED]
}
var current_color_index = 0

# --- TARGETING ---
var target_player_node: Node3D = null 
var main_camera: Camera3D = null

func _ready():
	_update_ui()

func _process(_delta):
	if target_player_node and main_camera:
		# 1. Get 3D Feet Position
		var feet_pos = target_player_node.global_position 
		
		# 2. Convert to 2D Screen Position
		var screen_pos = main_camera.unproject_position(feet_pos)
		
		# 3. Center it based on the Panel's actual size
		var panel_size = $PanelContainer.size
		
		# Start at the feet position
		var final_pos = screen_pos
		
		# Subtract half the width to center horizontally
		final_pos.x -= (panel_size.x / 2)
		
		# Add your custom offset (Nudge it!)
		final_pos += ui_offset
		
		# Apply
		global_position = final_pos

# --- PART BUTTONS ---
func _on_left_part_btn_pressed():
	current_part_index -= 1
	if current_part_index < 0: current_part_index = body_parts.size() - 1
	current_color_index = 0 
	_update_ui()

func _on_right_part_btn_pressed():
	current_part_index += 1
	if current_part_index >= body_parts.size(): current_part_index = 0
	current_color_index = 0
	_update_ui()

# --- COLOR BUTTONS ---
func _on_left_color_btn_pressed():
	var part_name = body_parts[current_part_index]
	var palette = palettes.get(part_name, palettes["Tunic"]) 
	
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
	
	var palette = palettes.get(part_name, palettes["Tunic"])
	if palette.size() > 0:
		color_display.color = palette[current_color_index]

func _apply_change():
	var part_name = body_parts[current_part_index]
	var palette = palettes.get(part_name, palettes["Tunic"])
	var selected_color = palette[current_color_index]
	
	color_display.color = selected_color
	
	# Send directly to Global (No RPC suffix needed here)
	Global.update_customization(part_name, selected_color)
