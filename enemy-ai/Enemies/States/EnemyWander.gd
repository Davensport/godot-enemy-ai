class_name EnemyWander
extends EnemyState

@export var wander_radius: float = 8.0
@export var wander_speed_ratio: float = 0.4 
@export var min_wait_time: float = 2.0
@export var max_wait_time: float = 4.0

var wander_time: float = 0.0

func enter():
	enemy.play_animation(stats.anim_move)
	
	# 1. Generate a valid target point relative to Home
	var move_target = _get_wander_point()
	
	# 2. Tell the movement component to go there
	if enemy.movement_component:
		enemy.movement_component.set_target_position(move_target)
	
	# Set a random timeout
	wander_time = randf_range(min_wait_time, max_wait_time)

func physics_update(delta):
	wander_time -= delta
	
	# --- NEW: Look for targets while walking ---
	# We perform the check every frame (or you could throttle this with a timer for optimization)
	var potential_target = enemy.get_weighted_player_target()
	if potential_target:
		var dist = enemy.global_position.distance_to(potential_target.global_position)
		if dist < stats.aggro_range:
			enemy.player_target = potential_target
			transition_requested.emit(self, "chase")
			return
	# -------------------------------------------

	# 2. Check if finished (Time out OR Destination reached)
	if wander_time <= 0 or _has_reached_destination():
		transition_requested.emit(self, "idle")
		return

	# 3. Apply Movement
	if stats.is_flying:
		_handle_flying_movement(delta)
	else:
		_handle_ground_movement(delta)

func _handle_ground_movement(delta):
	if enemy.movement_component:
		var chase_vel = enemy.movement_component.get_chase_velocity()
		chase_vel = chase_vel.normalized() * (stats.move_speed * wander_speed_ratio)
		
		enemy.velocity.x = move_toward(enemy.velocity.x, chase_vel.x, stats.acceleration * delta)
		enemy.velocity.z = move_toward(enemy.velocity.z, chase_vel.z, stats.acceleration * delta)
		
		if chase_vel.length_squared() > 0.1:
			enemy.rotate_smoothly(enemy.velocity, delta)

func _handle_flying_movement(delta):
	var target = enemy.movement_component.target_pos_override
	var dir = (target - enemy.global_position).normalized()
	
	var desired_velocity = dir * (stats.move_speed * wander_speed_ratio)
	enemy.velocity = enemy.velocity.lerp(desired_velocity, delta * 2.0)
	enemy.rotate_smoothly(enemy.velocity, delta)

func _has_reached_destination() -> bool:
	if not stats.is_flying and enemy.movement_component:
		return enemy.movement_component.nav_agent.is_navigation_finished()
	
	var dist = enemy.global_position.distance_to(enemy.movement_component.target_pos_override)
	return dist < 1.5

func _get_wander_point() -> Vector3:
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var random_dist = randf_range(2.0, wander_radius)
	var target_point = enemy.home_position + (random_dir * random_dist)
	
	if stats.is_flying:
		target_point.y = enemy.home_position.y + randf_range(-2.0, 4.0)
		return target_point
	else:
		var map = enemy.get_world_3d().navigation_map
		var valid_point = NavigationServer3D.map_get_closest_point(map, target_point)
		return valid_point
