extends EnemyState

@export var min_idle_time: float = 1.0
@export var max_idle_time: float = 3.0

var wander_timer: float = 0.0

func enter():
	enemy.play_animation(stats.anim_idle)
	enemy.velocity = Vector3.ZERO 
	
	# Randomize how long we chill before moving again
	wander_timer = randf_range(min_idle_time, max_idle_time)

func physics_update(delta):
	# 1. Apply Friction to stop sliding
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, stats.acceleration * delta)
	enemy.velocity.z = move_toward(enemy.velocity.z, 0, stats.acceleration * delta)

	# 2. TARGET ACQUISITION (Updated for Multiplayer)
	# Instead of always grabbing players[0], we ask the enemy for a weighted target.
	var potential_target = enemy.get_weighted_player_target()
	
	if potential_target:
		# Optional: Check distance/vision before fully committing
		# (e.g., only chase if within aggro_range)
		var dist = enemy.global_position.distance_to(potential_target.global_position)
		
		if dist <= stats.aggro_range:
			enemy.player_target = potential_target
			transition_requested.emit(self, "chase")
			return # Stop processing idle logic if we found a target

	# 3. Count down to Wander
	if wander_timer > 0:
		wander_timer -= delta
	else:
		transition_requested.emit(self, "wander")
