extends GearBase

func _ready() -> void:
	super._ready()
	_set_color("#fa0000")
	_set_label_text("D")

func _collect() -> void:
	TimelineManager.tutorial_text.emit("Attack damage increased", "past")
	_erase_interactive_tiles()
	queue_free()
	player.bonus_attack_damage += 1
	
