class_name EnemyDeath
extends EnemyState

func enter():
	enemy.play_animation(stats.anim_death)
	
	# 1. Disable Movement
	enemy.velocity = Vector3.ZERO
	
	# 2. Disable Collision (Deferred to be safe during physics step)
	if enemy.collision_shape:
		enemy.collision_shape.set_deferred("disabled", true)
	
	# 3. Handle Logic
	if enemy.auto_respawn:
		_handle_respawn()
	else:
		_handle_despawn()

func _handle_respawn():
	# Wait for the respawn timer
	await get_tree().create_timer(enemy.respawn_time).timeout
	
	# Reset Health
	enemy.health_component.reset_health()
	
	# Re-enable Collision
	if enemy.collision_shape:
		enemy.collision_shape.set_deferred("disabled", false)
		
	# Visual Reset (Optional: Maybe pop them back to spawn pos?)
	enemy.play_animation(stats.anim_idle)
	
	# Go back to Idle
	transition_requested.emit(self, "idle")

func _handle_despawn():
	# Wait a moment for the death animation to finish/body to settle
	await get_tree().create_timer(1.5).timeout
	
	# Sink into the ground effect (Tweens are great here)
	if enemy.visuals_container:
		var tween = create_tween()
		tween.tween_property(enemy.visuals_container, "position:y", -2.0, 2.0)
		await tween.finished
		
	enemy.queue_free()

# Block physics updates in death so gravity doesn't weirdly slide the corpse
func physics_update(_delta):
	# Only apply gravity if not flying, so they fall to the ground upon death
	if not stats.is_flying and not enemy.is_on_floor():
		enemy.velocity.y -= enemy.gravity * _delta
		enemy.move_and_slide()
