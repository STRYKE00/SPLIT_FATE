extends CanvasLayer

@onready var _root: Control = $Root
@onready var _label: Label = $Root/VBox/Label
@onready var _bar: ProgressBar = $Root/VBox/ProgressBar


func _ready() -> void:
	_root.visible = false
	_root.modulate.a = 1.0
	_bar.max_value = 20
	_bar.value = 20

	TimelineManager.boss_spawned.connect(_on_boss_spawned)
	TimelineManager.boss_hp_changed.connect(_on_hp_changed)
	TimelineManager.boss_defeated.connect(_on_boss_defeated)


func _on_boss_spawned(_boss: Node) -> void:
	_root.visible = true
	_root.modulate.a = 1.0
	_bar.max_value = 20
	_bar.value = 20
	_root.pivot_offset = _root.size * 0.5
	_root.scale = Vector2(0.05, 1.0)
	var tw := create_tween()
	tw.tween_property(_root, "scale", Vector2.ONE, 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_hp_changed(current: int, max_hp: int) -> void:
	_bar.max_value = max_hp
	var tw := create_tween()
	tw.tween_property(_bar, "value", current, 0.2)


func _on_boss_defeated(_timeline: String) -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _root.visible = false)
