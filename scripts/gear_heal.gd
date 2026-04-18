extends GearBase

func _ready() -> void:
	super._ready()
	_set_color("#34c83f")
	_set_label_text("H")

func _collect() -> void:
	super._collect()
	stats.heal(1)
