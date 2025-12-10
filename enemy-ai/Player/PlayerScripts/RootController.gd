class_name PlayerController
extends CharacterBody3D

# --- NEW: HUD VARIABLE ---
# Drag his "HUD.tscn" here in the inspector later!
@export var hud_scene: PackedScene

signal on_player_died

@onready var movement = $Components/Movement
@onready var combat = $Components/Combat
@onready var camera_rig = $Head/Camera3D
@onready var health = $Components/HealthComponent
@onready var AnimPlayer = $AnimationPlayer
@onready var AnimTree = $AnimationTree

var is_flying: bool = false
var _saved_collision_mask: int = 1

# [MULTIPLAYER] 1. Set Authority when spawned
func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	# [MULTIPLAYER] Only setup for the Local Player
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera_rig.current = true
		
		# --- HUD SPAWNING (MOVED HERE) ---
		if hud_scene:
			var hud = hud_scene.instantiate()
			add_child(hud)
			
			# Wire it up if it has the setup function
			if hud.has_method("setup_ui"):
				hud.setup_ui(self)
	else:
		# If it's NOT me, disable camera and physics
		camera_rig.current = false
		set_physics_process(false)

	if health:
		health.on_death.connect(_on_death_logic)

func _input(event):
	# [MULTIPLAYER] Guard rail for flying cheat
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
	# Note: This function only runs if is_multiplayer_authority() is true
	# because we disabled it in _ready() for others.
	
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

func take_damage(amount):
	# [MULTIPLAYER] Only the server deals damage
	if multiplayer.is_server():
		health.take_damage(amount)

func _on_death_logic():
	on_player_died.emit()
	
	# Stop moving/physics
	set_physics_process(false)
	
	# Play death animation
	AnimTree["parameters/LifeState/transition_request"] = "dead"
	AnimPlayer.stop()
	
	# --- FIX 1: UNCOMMENT THIS LINE ---
	# This sends the signal to the HUD so the button appears!
	SignalBus.player_died.emit() 
	
	# --- FIX 2: REMOVE THE TIMER AND QUEUE_FREE ---
	# We deleted the timer here.
	# Why? Because the HUD is now attached to the Player.
	# If we delete the Player automatically, the Death Screen deletes too!
	# We will let the "Respawn" button handle the cleanup.
