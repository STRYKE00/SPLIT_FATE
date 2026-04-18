extends GearBase

func _ready() -> void:
	super._ready()
	_set_color("#fa0000")
	_set_label_text("D")

func _collect() -> void:
	super._collect()
	player.bonus_attack_damage += 1
	
