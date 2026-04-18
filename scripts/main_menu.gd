extends Node2D

const FADE_DURATION     := 3.0
const BTN_FADE_DURATION := 0.6
const TITLE_FADE_DELAY  := 0.8
const TITLE_FADE_IN     := 1.2

@onready var title_sprite:  Sprite2D         = $CanvasLayer/TitleSprite
@onready var overlay:       ColorRect         = $CanvasLayer/BlackOverlay
@onready var play_btn:      TextureButton     = $CanvasLayer/PlayButton
@onready var credits_btn:   TextureButton     = $CanvasLayer/CreditsButton
@onready var music:         AudioStreamPlayer = $Music


func _ready() -> void:
	var stream := load("res://assets/ui/main_menu_music.mp3") as AudioStreamMP3
	stream.loop = true
	music.stream = stream
	music.play()

	overlay.color.a         = 1.0
	play_btn.modulate.a     = 0.0
	credits_btn.modulate.a  = 0.0
	title_sprite.modulate.a = 0.0

	var bg_tween := create_tween()
	bg_tween.tween_property(overlay, "color:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)

	var title_tween := create_tween()
	title_tween.tween_interval(TITLE_FADE_DELAY)
	title_tween.tween_property(title_sprite, "modulate:a", 1.0, TITLE_FADE_IN)\
		.set_ease(Tween.EASE_OUT)

	await bg_tween.finished

	var btn_tween := create_tween().set_parallel(true)
	btn_tween.tween_property(play_btn, "modulate:a", 1.0, BTN_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT)
	btn_tween.tween_property(credits_btn, "modulate:a", 1.0, BTN_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT)
	await btn_tween.finished

	play_btn.pressed.connect(_on_play_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)


func _on_play_pressed() -> void:
	play_btn.disabled = true
	credits_btn.disabled = true
	var fade := create_tween().set_parallel(true)
	fade.tween_property(play_btn, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_SINE)
	fade.tween_property(credits_btn, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_SINE)
	fade.tween_property(title_sprite, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN)
	fade.tween_property(overlay, "color:a", 1.0, 0.8)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_SINE)
	fade.tween_property(music, "volume_db", -40.0, 0.8)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/prologue.tscn")


func _on_credits_pressed() -> void:
	play_btn.disabled = true
	credits_btn.disabled = true
	var fade := create_tween().set_parallel(true)
	fade.tween_property(play_btn, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_SINE)
	fade.tween_property(credits_btn, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_SINE)
	fade.tween_property(title_sprite, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN)
	fade.tween_property(overlay, "color:a", 1.0, 0.8)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_SINE)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/credits.tscn")
