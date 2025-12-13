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
	# Apply Friction (Keep your existing friction logic) [cite: 5]
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, stats.acceleration * delta)
	enemy.velocity.z = move_toward(enemy.velocity.z, 0, stats.acceleration * delta)

	# 1. Check for player (High Priority)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		# Check distance/vision here if needed
		enemy.player_target = players[0]
		transition_requested.emit(self, "chase")
		return # Stop processing idle logic if we found a target

	# 2. Count down to Wander
	if wander_timer > 0:
		wander_timer -= delta
	else:
		transition_requested.emit(self, "wander")
