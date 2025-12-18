extends EnemyState

@export var min_idle_time: float = 1.0
@export var max_idle_time: float = 3.0

var wander_timer: float = 0.0

func enter():
	print("ENEMY IN IDLE STATE")
	enemy.play_animation(stats.anim_idle)
	enemy.velocity = Vector3.ZERO 
	
	# Randomize how long we chill before moving again
	wander_timer = randf_range(min_idle_time, max_idle_time)

func physics_update(delta):
	# Apply Friction (Keep your existing friction logic) [cite: 5]
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, stats.acceleration * delta)
	enemy.velocity.z = move_toward(enemy.velocity.z, 0, stats.acceleration * delta)

	# 1. Check for player (High Priority)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var target = players[0]
		var distance = enemy.global_position.distance_to(target.global_position)

		# FIX: Check if we are close enough to care!
		# Assuming 'aggro_range' is in your stats, or use a hard number like 10.0
		var aggro_range = stats.aggro_range if "aggro_range" in stats else 10.0
		
		if distance <= aggro_range:
			enemy.player_target = target
			transition_requested.emit(self, "chase")
			return 

	# 2. Count down to Wander
	if wander_timer > 0:
		wander_timer -= delta
	else:
		transition_requested.emit(self, "wander")
