extends GearBase

func _ready() -> void:
	super._ready()
	_set_color("#34c83f")
	_set_label_text("H")

func _collect() -> void:
	TimelineManager.tutorial_text.emit("Restore health", "future")
	_erase_interactive_tiles()
	queue_free()
	stats.heal(1)
