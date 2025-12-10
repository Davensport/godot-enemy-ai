class_name MeleeWeapon
extends Area3D

@export var damage: int = 20
@export var currently_attacking: bool = false
var hit_objects: Array[Node] = []
func _ready():
	monitoring = false
	body_entered.connect(_on_body_entered)

func attack():
	# 1. Reset the list for the new swing
	hit_objects.clear()
	
	currently_attacking = true
	monitoring = true
	
	# 2. Swing duration (match this to your animation speed)
	await get_tree().create_timer(0.6).timeout
	
	monitoring = false
	currently_attacking = false

func _on_body_entered(body):
	if body.is_in_group('player'):
		return
	# 1. Check if we already hit this specific enemy during this specific swing
	if body in hit_objects:
		return # Ignore them, they already took damage
	
	# 2. Add them to the "Already Hit" list
	hit_objects.append(body)
	if body.has_method("take_damage"):
		body.take_damage(damage)
