extends Resource
class_name EnemyStats

@export_group("Vitality")
@export var max_health: float = 100.0

@export_group("Movement")
@export var move_speed: float = 4.0
@export var acceleration: float = 10.0

@export_group("Combat")
@export var attack_damage: float = 10.0
@export var attack_range: float = 2.0
@export var attack_rate: float = 1.5 # Seconds between attacks
@export var aggro_range: float = 12.0
@export var deaggro_range: float = 16.0

@export_group("Visuals")
@export var enemy_name: String = "Enemy"
@export var model_scene: PackedScene  
@export var scale: float = 1.0
@export var model_rotation_y: float = 0.0


# IF PROJECTILE

@export_group("Magic Settings")
# The fireball/magic bolt object to spawn
@export var projectile_scene: PackedScene 
@export var projectile_speed: float = 10.0
#@export var cast_color: Color = Color.PURPLE # Optional: for particle effects


@export_group("Movement Settings")
@export var is_flying: bool = false
@export var turn_speed: float = 5.0 # How fast they turn/adjust direction

@export_group("Animation Map")
@export_subgroup("State Names")
# Default values act as a fallback
@export var anim_idle: String = "Idle"
@export var anim_move: String = "Run"
@export var anim_attack: String = "Attack"
@export var anim_death: String = "Death"
@export var anim_hit: String = "Hit"

@export_subgroup("Animation Settings")
@export var animation_blend_time: float = 0.
