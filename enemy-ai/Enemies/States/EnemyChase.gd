extends EnemyState

# Timer to prevent the enemy from switching targets every single frame
var retarget_timer: float = 0.0

func enter():
	enemy.play_animation(stats.anim_move)
	
	# Initial Setup: Lock onto the target immediately
	if enemy.movement_component and is_instance_valid(enemy.player_target):
		enemy.movement_component.set_target(enemy.player_target)
	
	# Randomize the timer slightly so all enemies don't "think" at the exact same millisecond
	retarget_timer = randf_range(0.5, 1.0)

func physics_update(delta):
	# 1. SAFETY CHECK: If target is invalid (disconnected/deleted), try to find a new one
	if not is_instance_valid(enemy.player_target):
		var recovered_target = enemy.get_weighted_player_target()
		if recovered_target:
			enemy.player_target = recovered_target
		else:
			transition_requested.emit(self, "idle")
			return

	var distance = enemy.global_position.distance_to(enemy.player_target.global_position)
	
	# 2. DYNAMIC RETARGETING
	# Every 1-2 seconds, check if there is a "better" (closer) target available.
	retarget_timer -= delta
	if retarget_timer <= 0:
		retarget_timer = randf_range(1.0, 2.0)
		_check_for_better_target()

	# 3. DE-AGGRO CHECK
	# If current target runs too far, give up.
	if distance > stats.deaggro_range:
		enemy.player_target = null 
		transition_requested.emit(self, "wander") 
		return

	# 4. MOVEMENT LOGIC
	if stats.is_flying:
		_handle_flying_movement(delta)
	else:
		_handle_ground_movement(delta)

	# 5. ATTACK TRANSITION
	# Fix: Added a small buffer (+0.5) to 'attack_range'. 
	# This ensures the enemy attacks even if the nav agent stops slightly early.
	if distance <= stats.attack_range + 0.5:
		if enemy.combat_component.has_line_of_sight():
			transition_requested.emit(self, "attack")

func _check_for_better_target():
	# Ask the enemy main script for a target based on weighted distance
	var potential_target = enemy.get_weighted_player_target()
	
	# If we found a valid target that is NOT our current target
	if potential_target and potential_target != enemy.player_target:
		var current_dist = enemy.global_position.distance_to(enemy.player_target.global_position)
		var new_dist = enemy.global_position.distance_to(potential_target.global_position)
		
		# Hysteresis: Only switch if the new target is actually closer (by at least 1 meter)
		# This prevents "jitters" where the enemy can't decide between two nearby players.
		if new_dist < current_dist - 1.0:
			enemy.player_target = potential_target
			
			# Update the movement component immediately
			if enemy.movement_component:
				enemy.movement_component.set_target(enemy.player_target)

func _handle_flying_movement(delta):
	enemy.flight_offset_time += delta
	var bob_amount = sin(enemy.flight_offset_time * 2.0) * 1.5 
	var target_pos = enemy.player_target.global_position + Vector3(0, 4.0 + bob_amount, 0)
	
	var direction = (target_pos - enemy.global_position).normalized()
	enemy.velocity = enemy.velocity.lerp(direction * stats.move_speed, delta * 5.0)
	enemy.rotate_smoothly(enemy.velocity, delta)

func _handle_ground_movement(delta):
	if enemy.movement_component:
		# Update target position in case the player moved
		enemy.movement_component.set_target(enemy.player_target)
		
		var chase_vel = enemy.movement_component.get_chase_velocity()
		
		enemy.velocity.x = move_toward(enemy.velocity.x, chase_vel.x, stats.acceleration * delta)
		enemy.velocity.z = move_toward(enemy.velocity.z, chase_vel.z, stats.acceleration * delta)
		
		if chase_vel.length_squared() > 0.1:
			enemy.rotate_smoothly(enemy.velocity, delta)
		else:
			enemy.movement_component.look_at_target()
