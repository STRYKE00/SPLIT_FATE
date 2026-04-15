extends CanvasLayer

signal restart_requested
signal menu_requested

@onready var _root: Control = $Root
@onready var _restart_button: Button = $Root/Panel/VBox/RestartButton
@onready var _menu_button: Button = $Root/Panel/VBox/MenuButton


func _ready() -> void:
	_root.visible = false
	_restart_button.pressed.connect(func(): restart_requested.emit())
	_menu_button.pressed.connect(func(): menu_requested.emit())


func show_game_over() -> void:
	_root.visible = true
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.5)
	await tw.finished
	_restart_button.grab_focus()
