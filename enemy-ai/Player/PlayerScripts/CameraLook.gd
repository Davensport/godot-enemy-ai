class_name CameraComponent
extends Node3D

@export var body_to_rotate: CharacterBody3D
@export_group("Settings")
@export var sensitivity: float = 0.003
@export var max_look_angle: float = 40.0
@export var min_look_angle: float = -60.0

@export_group("Visuals")
@export var skeleton: Skeleton3D
@export var spine_bone_name: String = "Spine"
var _spine_bone_idx: int = -1

func _ready():
	# [MULTIPLAYER] Only capture mouse if this is MY player
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	process_priority = 1
	
	if skeleton:
		_spine_bone_idx = skeleton.find_bone(spine_bone_name)

func _input(event):
	# [MULTIPLAYER] STOP! If I don't own this cam, ignore mouse
	if not is_multiplayer_authority():
		return

	# Toggle Mouse Mode with Middle Click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			toggle_mouse_mode()

	# Handle Rotation
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if body_to_rotate:
			body_to_rotate.rotate_y(-event.relative.x * sensitivity)
		rotate_x(-event.relative.y * sensitivity)
		rotation_degrees.x = clamp(rotation_degrees.x, min_look_angle, max_look_angle)

func _process(_delta):
	# [MULTIPLAYER] Visual spine bending happens for everyone so we can see other players look up/down
	if skeleton and _spine_bone_idx != -1:
		var spine_rotation = Quaternion(Vector3.RIGHT, -rotation.x)
		skeleton.set_bone_pose_rotation(_spine_bone_idx, spine_rotation)

func toggle_mouse_mode():
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
