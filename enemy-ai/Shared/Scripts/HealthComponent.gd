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

func take_damage(amount: float):
	if current_health <= 0:
		return # Already dead

	current_health -= amount
	current_health = max(0.0, current_health) # Prevent negative HP
	
	on_damage_taken.emit(amount)
	on_health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		die()

func heal(amount: float):
	if current_health <= 0:
		return 
		
	current_health += amount
	current_health = min(current_health, max_health)
	
	on_health_changed.emit(current_health, max_health)

func die():
	on_death.emit()
	
func reset_health():
	current_health = max_health
	on_health_changed.emit(current_health, max_health)
