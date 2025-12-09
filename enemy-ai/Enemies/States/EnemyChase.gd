extends EnemyState

func enter():
	enemy.play_animation(stats.anim_move)

func physics_update(delta):
	if not is_instance_valid(enemy.player_target):
		transition_requested.emit(self, "idle")
		return

	var distance = enemy.global_position.distance_to(enemy.player_target.global_position)
	
	# --- MOVEMENT LOGIC ---
	if stats.is_flying:
		_handle_flying_movement(delta)
	else:
		_handle_ground_movement(delta)

	# --- TRANSITION CHECKS ---
	var range_check = stats.attack_range
	if distance <= range_check:
		if enemy.combat_component.has_line_of_sight():
			transition_requested.emit(self, "attack")

func _handle_flying_movement(delta):
	enemy.flight_offset_time += delta
	var bob_amount = sin(enemy.flight_offset_time * 2.0) * 1.5 
	var target_pos = enemy.player_target.global_position + Vector3(0, 4.0 + bob_amount, 0)
	
	var direction = (target_pos - enemy.global_position).normalized()
	enemy.velocity = enemy.velocity.lerp(direction * stats.move_speed, delta * 5.0)
	enemy.rotate_smoothly(enemy.velocity, delta)

func _handle_ground_movement(delta):
	if enemy.movement_component:
		enemy.movement_component.set_target(enemy.player_target)
		var chase_vel = enemy.movement_component.get_chase_velocity()
		enemy.velocity.x = move_toward(enemy.velocity.x, chase_vel.x, stats.acceleration * delta)
		enemy.velocity.z = move_toward(enemy.velocity.z, chase_vel.z, stats.acceleration * delta)
		enemy.rotate_smoothly(enemy.velocity, delta)
