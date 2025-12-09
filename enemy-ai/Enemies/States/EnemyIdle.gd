extends EnemyState

func enter():
	enemy.play_animation(stats.anim_idle)
	enemy.velocity = Vector3.ZERO # Stop initial momentum

func physics_update(delta):
	# Fix: Continuously apply friction/stop movement
	# If we don't do this, gravity or a slight bump will make them slide forever.
	enemy.velocity.x = move_toward(enemy.velocity.x, 0, stats.acceleration * delta)
	enemy.velocity.z = move_toward(enemy.velocity.z, 0, stats.acceleration * delta)

	# Check for player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		enemy.player_target = players[0]
		transition_requested.emit(self, "chase")
