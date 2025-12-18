# SignalBus.gd
extends Node

# Emitted when the player is instantiated/spawned
# Useful for: Enemies finding the player, Camera locking on
signal player_spawned(player_node)

# Emitted when the player dies (HP <= 0)
# Useful for: triggering the Death Screen, stopping music, disabling inputs
signal player_died

# Emitted when the UI "Respawn" button is clicked
# Useful for: The PlayerSpawner knowing it is time to reset the level
signal respawn_requested


# New signals for enemies
# Emitted by EnemyCombatComponent
signal enemy_attack_occurred(enemy_root: Node, damage: float)

# Emitted by HealthComponent or BaseEnemy
signal enemy_died(enemy_root: Node)

# Emitted by BaseEnemy (optional, for UI)
signal enemy_health_changed(enemy_root: Node, new_value: float, max_value: float)
