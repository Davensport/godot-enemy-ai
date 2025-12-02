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

@export_group("Visuals")
@export var enemy_name: String = "Enemy"
@export var model_scene: PackedScene  
@export var scale: float = 1.0
