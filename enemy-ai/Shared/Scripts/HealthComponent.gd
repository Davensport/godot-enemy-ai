class_name HealthComponent
extends Node

# Changed types to float for better compatibility with game math
signal on_health_changed(current_hp: float, max_hp: float)
signal on_damage_taken(amount: float)
signal on_death

@export var max_health: float = 100.0
@export var start_full: bool = true

var current_health: float

func _ready():
	if start_full:
		current_health = max_health
	else:
		current_health = 0.0

# --- NEW FUNCTION FOR RESOURCE SYSTEM ---
func initialize(new_max_hp: float):
	max_health = new_max_hp
	current_health = max_health
	# Emit immediately so UI updates before the game really starts
	on_health_changed.emit(current_health, max_health)

# Add this RPC tag so Clients can call this function on the Server
@rpc("any_peer", "call_local")
func take_damage(amount: float):
	# 1. SECURITY CHECK
	# Only the Server is allowed to actually lower the health numbers.
	# This prevents "cheating" and sync issues.
	if not multiplayer.is_server():
		# If I am a Client, I must ask the Server to do it for me.
		take_damage.rpc_id(1, amount)
		return

	# 2. SERVER LOGIC (Only runs on the Host)
	current_health -= amount
	current_health = clamp(current_health, 0, max_health)
	
	# Emit signal so UI/Healthbars update
	# (Note: You might need a separate SyncVar for health if you want Client UI to update instantly)
	on_health_changed.emit(current_health, max_health)
	
	print("Enemy took damage. Current HP: ", current_health)

	if current_health <= 0:
		die()

func heal(amount: float):
	if current_health <= 0:
		return 
		
	current_health += amount
	current_health = min(current_health, max_health)
	
	on_health_changed.emit(current_health, max_health)

func die():
	# Ensure only the server triggers death to prevent double-deaths
	if not multiplayer.is_server(): return
	
	on_death.emit()
	
	# If this is an Enemy, we usually queue_free() it.
	# Since it was spawned by a MultiplayerSpawner, deleting it on Server
	# deletes it for EVERYONE automatically.
	get_parent().queue_free()
	
func reset_health():
	current_health = max_health
	on_health_changed.emit(current_health, max_health)
