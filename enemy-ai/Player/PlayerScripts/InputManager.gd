class_name InputComponent
extends Node

# --- SIGNALS ---
signal on_jump
signal on_attack_sword
signal on_attack_fireball
signal on_interact

# New Signals for Movement to listen to
signal on_crouch_press
signal on_crouch_release

# --- STATE ---
var input_dir: Vector2 = Vector2.ZERO
var is_crouch_held: bool = false 

func _process(_delta):
	# [MULTIPLAYER] GUARD RAIL
	# If I do not own this character, I cannot press buttons for it.
	if not is_multiplayer_authority():
		return

	# 1. Movement Input
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# 2. Crouch State Logic
	if Input.is_action_just_pressed("crouch"):
		is_crouch_held = true
		on_crouch_press.emit()
		
	if Input.is_action_just_released("crouch"):
		is_crouch_held = false
		on_crouch_release.emit()

	# 3. Action Signals
	if Input.is_action_just_pressed("jump"):
		on_jump.emit()
	
	if Input.is_action_just_pressed("attack_primary"):
		on_attack_sword.emit()
		
	if Input.is_action_just_pressed("attack_secondary"):
		on_attack_fireball.emit()

	if Input.is_action_just_pressed("interact"):
		on_interact.emit()
