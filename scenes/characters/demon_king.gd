extends EnemyBase


func _ready() -> void:
	sprite.play("idle")
	_init_configs()
