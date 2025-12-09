class_name EnemyState
extends Node

signal transition_requested(from: EnemyState, to: String)

# References injected by the StateMachine
var enemy: DummyEnemy 
var stats: EnemyStats 

# Virtual methods to be overridden
func enter():
	pass

func exit():
	pass

func physics_update(_delta: float):
	pass
