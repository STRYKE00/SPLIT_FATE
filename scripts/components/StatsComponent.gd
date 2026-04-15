extends Node
class_name StatsComponent

@export var max_hp: int = 5

var hp: int = 0
var is_dead: bool = false
var invincible: bool = false

signal hp_changed(new_hp: int, max_hp: int)
signal hurt(damage: int)
signal died()


func _ready() -> void:
	hp = max_hp


func take_damage(amount: int) -> void:
	if is_dead or invincible:
		return
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	hurt.emit(amount)
	if hp <= 0:
		is_dead = true
		died.emit()


func heal(amount: int) -> void:
	if is_dead:
		return
	hp = min(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func reset() -> void:
	hp = max_hp
	is_dead = false
	invincible = false
	hp_changed.emit(hp, max_hp)
