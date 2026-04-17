extends Node

const BOSS_SCENE_PATH := "res://scenes/Boss_Room.tscn"
const MAIN_MENU_PATH := "res://scenes/main_menu.tscn"

var _layer: CanvasLayer
var _button: Button

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_button = Button.new()
	_button.text = "Skip → Boss"
	_button.anchor_left = 1.0
	_button.anchor_right = 1.0
	_button.offset_left = -140
	_button.offset_top = 12
	_button.offset_right = -12
	_button.offset_bottom = 40
	_button.focus_mode = Control.FOCUS_NONE
	_layer.add_child(_button)
	_button.pressed.connect(_on_pressed)

	get_tree().tree_changed.connect(_refresh_visibility)
	_refresh_visibility()

func _refresh_visibility() -> void:
	var cur := get_tree().current_scene
	if cur == null:
		_button.visible = false
		return
	_button.visible = cur.scene_file_path != MAIN_MENU_PATH

func _on_pressed() -> void:
	GameState.is_dialogue_active = false
	GameState.is_transitioning = false
	get_tree().change_scene_to_file(BOSS_SCENE_PATH)
