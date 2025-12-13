extends EnemyState

func enter():
	enemy.play_animation(stats.anim_move)
	
	# Pass the target to the movement component immediately upon entering
	if enemy.movement_component and is_instance_valid(enemy.player_target):
		enemy.movement_component.set_target(enemy.player_target)

func physics_update(delta):
	# 1. Safety Check: If target is deleted or invalid, return to idle
	if not is_instance_valid(enemy.player_target):
		transition_requested.emit(self, "idle")
		return

	var distance = enemy.global_position.distance_to(enemy.player_target.global_position)
	
	# 2. De-Aggro Check ("Give Up")
	# If the player runs far enough away (exceeds deaggro_range), stop chasing.
	if distance > stats.deaggro_range:
		enemy.player_target = null # Forget the target so we don't immediately re-aggro
		transition_requested.emit(self, "wander") 
		return

	# 3. Movement Logic
	if stats.is_flying:
		_handle_flying_movement(delta)
	else:
		_handle_ground_movement(delta)

	# 4. Attack Transition Check
	# We check if we are within range AND have line of sight
	if distance <= stats.attack_range:
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
		# Update the component's target (in case the player moved)
		enemy.movement_component.set_target(enemy.player_target)
		
		# Get the calculated velocity from the component (handles pathfinding/navmesh)
		var chase_vel = enemy.movement_component.get_chase_velocity()
		
		# Apply movement
		enemy.velocity.x = move_toward(enemy.velocity.x, chase_vel.x, stats.acceleration * delta)
		enemy.velocity.z = move_toward(enemy.velocity.z, chase_vel.z, stats.acceleration * delta)
		
		# Rotation handling
		if chase_vel.length_squared() > 0.1:
			enemy.rotate_smoothly(enemy.velocity, delta)
		else:
			# If we are stopped (e.g., waiting for path calculation), look at the player
			enemy.movement_component.look_at_target()
