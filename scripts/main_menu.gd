extends Node2D

const FADE_DURATION     := 3.0
const BTN_FADE_DURATION := 0.6
const TITLE_FADE_DELAY  := 0.8
const TITLE_FADE_IN     := 1.2
const BTN_FPS           := 8.0

@onready var title_sprite: Sprite2D         = $CanvasLayer/TitleSprite
@onready var overlay:      ColorRect         = $CanvasLayer/BlackOverlay
@onready var play_btn:     TextureButton     = $CanvasLayer/PlayButton
@onready var anim_player:  AnimationPlayer  = $CanvasLayer/PlayButton/AnimationPlayer
@onready var music:        AudioStreamPlayer = $Music


func _ready() -> void:
	var stream := load("res://assets/ui/main_menu_music.mp3") as AudioStreamMP3
	stream.loop = true
	music.stream = stream
	music.play()

	overlay.color.a         = 1.0
	play_btn.modulate.a     = 0.0
	title_sprite.modulate.a = 0.0

	_build_button_animation()

	var bg_tween := create_tween()
	bg_tween.tween_property(overlay, "color:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)

	var title_tween := create_tween()
	title_tween.tween_interval(TITLE_FADE_DELAY)
	title_tween.tween_property(title_sprite, "modulate:a", 1.0, TITLE_FADE_IN)\
		.set_ease(Tween.EASE_OUT)

	await bg_tween.finished

	var btn_tween := create_tween()
	btn_tween.tween_property(play_btn, "modulate:a", 1.0, BTN_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT)
	await btn_tween.finished

	anim_player.play("idle")
	play_btn.pressed.connect(_on_play_pressed)


func _build_button_animation() -> void:
	var frame_time := 1.0 / BTN_FPS
	var total_len  := 16.0 * frame_time

	var anim := Animation.new()
	anim.length    = total_len
	anim.loop_mode = Animation.LOOP_LINEAR

	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, ".:texture_normal")
	anim.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)

	for i in 16:
		var tex: Texture2D = load("res://assets/ui/play_button_%d.png" % (i + 1))
		anim.track_insert_key(track, i * frame_time, tex)

	var lib := AnimationLibrary.new()
	lib.add_animation("idle", anim)
	anim_player.add_animation_library("", lib)


func _on_play_pressed() -> void:
	play_btn.disabled = true
	anim_player.stop()
	var fade := create_tween().set_parallel(true)
	fade.tween_property(play_btn, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_SINE)
	fade.tween_property(title_sprite, "modulate:a", 0.0, 0.8)\
		.set_ease(Tween.EASE_IN)
	fade.tween_property(overlay, "color:a", 1.0, 0.8)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_SINE)
	fade.tween_property(music, "volume_db", -40.0, 0.8)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
