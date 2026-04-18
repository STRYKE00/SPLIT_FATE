extends Node2D

const MAIN_MENU_PATH := "res://scenes/main_menu.tscn"
const EPILOGUE_PATH := "res://Epilogue.tscn"
const OUTRO_DELAY := 2.0
const SOLAN_SCENE := preload("res://scenes/characters/Solan.tscn")
const PORTAL_SCENE := preload("res://Portal_epilogue.tscn")

@onready var _demon_king: Node = $DemonKing
@onready var _past: Node = $PlayerPast
@onready var _future: Node = $PlayerFuture
@onready var _hud: CanvasLayer = $BossHUD

var _past_dead := false
var _future_dead := false
var _victory_fired := false
var _defeat_fired := false

var _overlay: ColorRect
var _title_layer: CanvasLayer
var _title_label: Label
var _solen: Node
var _dialogue_box: Node
var _cutscene_active := true
var _cutscene_camera: Camera2D


func _ready() -> void:
	GameState.is_transitioning = true
	GameState.is_dialogue_active = false
	TimelineManager.player_died.connect(_on_player_died)
	TimelineManager.boss_defeated.connect(_on_boss_defeated)

	# Apply HP carried over from area1
	if GameState.past_player_hp >= 0 and _past:
		_past.stats.hp = GameState.past_player_hp
		_past.stats.hp_changed.emit(_past.stats.hp, _past.stats.max_hp)
		GameState.past_player_hp = -1
	if GameState.future_player_hp >= 0 and _future:
		_future.stats.hp = GameState.future_player_hp
		_future.stats.hp_changed.emit(_future.stats.hp, _future.stats.max_hp)
		GameState.future_player_hp = -1

	# Hide HUD and demon king during cutscene
	if _hud:
		_hud.visible = false
	if _demon_king:
		_demon_king.visible = false
		_demon_king.set_physics_process(false)
		_demon_king.set_process(false)

	# Freeze players during cutscene
	_past.set_physics_process(false)
	_future.set_physics_process(false)

	# Disable player cameras, use cutscene camera centered on room
	_past.camera.enabled = false
	_future.camera.enabled = false
	_cutscene_camera = Camera2D.new()
	_cutscene_camera.position = Vector2(688, 400)
	_cutscene_camera.zoom = Vector2(2, 2)
	_cutscene_camera.enabled = true
	add_child(_cutscene_camera)

	# Place players at screen edges so they walk inward
	_past.position = Vector2(520, 400)
	_future.position = Vector2(856, 400)

	# Spawn Solen at top of triangle (freeze movement during cutscene)
	_solen = SOLAN_SCENE.instantiate()
	_solen.position = Vector2(688, 350)
	_solen.z_index = 10
	_solen.set_physics_process(false)
	_solen.set_process(false)
	(_solen as Solen).set_state(Solen.STATE.IDLE_PAST)
	add_child(_solen)

	# Build overlay and dialogue box
	_build_overlay()
	_spawn_dialogue_box()

	# Start cutscene
	_run_cutscene()


func _build_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	add_child(canvas)
	_overlay = ColorRect.new()
	_overlay.size = Vector2(1376, 768)
	_overlay.color = Color(0, 0, 0, 1)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_overlay)

	# Title card layer (above overlay)
	_title_layer = CanvasLayer.new()
	_title_layer.layer = 60
	add_child(_title_layer)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.anchor_left = 0.0
	_title_label.anchor_top = 0.0
	_title_label.anchor_right = 1.0
	_title_label.anchor_bottom = 1.0
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.visible = false
	_title_layer.add_child(_title_label)


func _spawn_dialogue_box() -> void:
	_dialogue_box = preload("res://scenes/ui/DialogueBox.tscn").instantiate()
	add_child(_dialogue_box)


func _run_cutscene() -> void:
	# === Phase 1: The Convergence ===
	# Screen starts black, fade in over 3 seconds
	await get_tree().create_timer(1.0).timeout
	var fade_in := create_tween()
	fade_in.tween_property(_overlay, "color:a", 0.0, 3.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await fade_in.finished

	# Brief pause — silence, nobody speaks
	await get_tree().create_timer(1.5).timeout

	# === Phase 2: Reunion ===
	# Mira and Ren see each other — walk toward each other
	_past.sprite.play("walk")
	_future.sprite.play("walk")
	_future.sprite.flip_h = true
	var embrace_tw := create_tween().set_parallel(true)
	embrace_tw.tween_property(_past, "position", Vector2(668, 420), 1.2)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	embrace_tw.tween_property(_future, "position", Vector2(708, 420), 1.2)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await embrace_tw.finished
	_past.sprite.play("idle")
	_future.sprite.play("idle")

	# Hold embrace for 3 seconds
	await get_tree().create_timer(3.0).timeout

	# Reunion dialogue
	await _play_dialogue("res://data/dialogue/boss_cutscene_reunion.json")

	# === Phase 3: Gratitude to Solen ===
	# Mira turns toward Solen
	_past.sprite.play("walk")
	_future.sprite.play("walk")
	var approach_tw := create_tween().set_parallel(true)
	approach_tw.tween_property(_past, "position", Vector2(580, 450), 0.6)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	approach_tw.tween_property(_future, "position", Vector2(796, 450), 0.6)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	await approach_tw.finished
	_past.sprite.play("idle")
	_future.sprite.play("idle")

	(_solen as Solen).set_state(Solen.STATE.TALK)
	await _play_dialogue("res://data/dialogue/boss_cutscene_gratitude.json")

	# === Phase 4: The Revelation ===
	(_solen as Solen).set_state(Solen.STATE.TURN_AWAY)
	await get_tree().create_timer(1.0).timeout

	await _play_dialogue("res://data/dialogue/boss_cutscene_betrayal.json")

	# === Phase 5: Transformation ===
	# Solen raises arms — urgent_boss animation
	(_solen as Solen).set_state(Solen.STATE.URGENT_BOSS)
	await get_tree().create_timer(1.5).timeout

	# Violet energy — modulate Solen with cracks of purple
	var crack_tw := create_tween()
	crack_tw.tween_property(_solen.get_node("AnimatedSprite2D"), "modulate",
		Color(0.6, 0.2, 0.8, 1.0), 1.5)
	await crack_tw.finished

	# Ground trembles — camera shake
	await _camera_shake(0.8, 6.0)

	# White flash
	_overlay.color = Color(1, 1, 1, 0)
	var flash_tw := create_tween()
	flash_tw.tween_property(_overlay, "color:a", 1.0, 0.3)
	await flash_tw.finished

	# Remove Solen, show Demon King
	_solen.queue_free()
	_solen = null

	# === Title Card ===
	# Full white/black screen — hold for silence
	_overlay.color = Color(0, 0, 0, 1)
	await get_tree().create_timer(1.0).timeout

	# Show title card text
	_title_label.text = "The guide was never real.\n\nSolen\nthe Demon King\n\nHe was the threat all along."
	_title_label.visible = true
	_title_label.modulate.a = 0.0
	var title_in := create_tween()
	title_in.tween_property(_title_label, "modulate:a", 1.0, 0.8)
	await title_in.finished

	# Hold title for 2.5 seconds
	await get_tree().create_timer(2.5).timeout

	# Fade out title
	var title_out := create_tween()
	title_out.tween_property(_title_label, "modulate:a", 0.0, 0.6)
	await title_out.finished
	_title_label.visible = false

	# === Reveal Demon King ===
	# Position demon king where Solen was
	if _demon_king:
		_demon_king.position = Vector2(688, 400)
		_demon_king.visible = true

	# Position players for battle stance
	_past.position = Vector2(588, 450)
	_future.position = Vector2(788, 450)

	# Fade in from black
	var reveal_tw := create_tween()
	reveal_tw.tween_property(_overlay, "color:a", 0.0, 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await reveal_tw.finished

	# Camera shake on beat drop
	await _camera_shake(0.4, 8.0)

	# Final dialogue
	await _play_dialogue("res://data/dialogue/boss_cutscene_final.json")

	# === Battle begins ===
	# Start boss music
	AudioManager.play_bgm(preload("res://assets/Sounds/Boss_music.MP3"))

	# Enable demon king
	if _demon_king:
		_demon_king.set_physics_process(true)
		_demon_king.set_process(true)

	# Enable players — camera stays centered, zooms based on player distance
	_past.set_physics_process(true)
	_future.set_physics_process(true)
	_future.sprite.flip_h = false

	# Show HUD
	if _hud:
		_hud.visible = true
		_hud.connect_player_past(_past)
		_hud.connect_player_future(_future)

	# End cutscene
	_cutscene_active = false
	GameState.is_transitioning = false


func _play_dialogue(path: String) -> void:
	DialogueManager.start_dialogue(path)
	await DialogueManager.dialogue_ended


func _process(_delta: float) -> void:
	if _cutscene_active or not _cutscene_camera or not _demon_king:
		return
	# Camera follows demon king
	_cutscene_camera.position = _cutscene_camera.position.lerp(_demon_king.position, 0.1)
	# Zoom out enough to keep both players visible
	var half_vp := Vector2(688.0, 384.0)
	var margin := 80.0
	var max_offset := Vector2.ZERO
	for player in [_past, _future]:
		var diff :Vector2= (player.position - _cutscene_camera.position).abs()
		max_offset.x = max(max_offset.x, diff.x)
		max_offset.y = max(max_offset.y, diff.y)
	var zoom_x := half_vp.x / (max_offset.x + margin)
	var zoom_y := half_vp.y / (max_offset.y + margin)
	var z: float = min(zoom_x, zoom_y)
	z = clamp(z, 0.8, 3.0)
	_cutscene_camera.zoom = _cutscene_camera.zoom.lerp(Vector2(z, z), 0.05)


func _camera_shake(duration: float, intensity: float) -> void:
	var original_pos := position
	var elapsed := 0.0
	while elapsed < duration:
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		position = original_pos + offset
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	position = original_pos


func _on_player_died(timeline: String) -> void:
	if _cutscene_active:
		return
	if timeline == "past":
		_past_dead = true
	elif timeline == "future":
		_future_dead = true
	if _past_dead and _future_dead and not _victory_fired and not _defeat_fired:
		_victory_fired = true
		AudioManager.stop_bgm()
		await get_tree().create_timer(OUTRO_DELAY).timeout
		get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_boss_defeated(_timeline: String, last_pos: Vector2) -> void:
	if _cutscene_active:
		return
	if _defeat_fired:
		return
	_defeat_fired = true
	_cutscene_active = true
	GameState.is_transitioning = true
	AudioManager.stop_bgm()

	# Freeze players
	_past.set_physics_process(false)
	_future.set_physics_process(false)

	# Fade to black
	_overlay.color = Color(0, 0, 0, 0)
	var fade_out := create_tween()
	fade_out.tween_property(_overlay, "color:a", 1.0, 1.5)
	await fade_out.finished

	# Hide demon king and HUD
	if _demon_king:
		_demon_king.visible = false
		_demon_king.set_physics_process(false)
		_demon_king.set_process(false)
	if _hud:
		_hud.visible = false

	# Restore players to full HP and ensure they are fully visible
	_past.stats.hp = _past.stats.max_hp
	_past.stats.hp_changed.emit(_past.stats.hp, _past.stats.max_hp)
	_past.modulate = Color(1, 1, 1, 1)
	_past.sprite.modulate = Color(1, 1, 1, 1)
	_future.stats.hp = _future.stats.max_hp
	_future.stats.hp_changed.emit(_future.stats.hp, _future.stats.max_hp)
	_future.modulate = Color(1, 1, 1, 1)
	_future.sprite.modulate = Color(1, 1, 1, 1)
	var past_anim :AnimatedSprite2D= _past.get_node_or_null("Sprite")
	if past_anim :
		past_anim.play("idle")
	var future_anim :AnimatedSprite2D= _future.get_node_or_null("Sprite")
	if future_anim :
		future_anim.play("idle")
		
	future_anim.flip_h = true 
	_solen = SOLAN_SCENE.instantiate()
	_solen.position = last_pos
	_solen.z_index = 10
	_solen.set_physics_process(false)
	_solen.set_process(false)
	(_solen as Solen).set_state(Solen.STATE.IDLE_PAST)
	add_child(_solen)

	# Position players near Solen
	_past.position = last_pos + Vector2(-80, 60)
	_future.position = last_pos + Vector2(80, 60)

	# Move camera to Solen
	if _cutscene_camera:
		_cutscene_camera.position = last_pos
		_cutscene_camera.zoom = Vector2(2, 2)

	await get_tree().create_timer(1.0).timeout

	# Fade in — reveal Solen reverted
	var fade_in := create_tween()
	fade_in.tween_property(_overlay, "color:a", 0.0, 1.5)
	await fade_in.finished

	# Solen's grief dialogue
	(_solen as Solen).set_state(Solen.STATE.TALK)
	await _play_dialogue("res://data/dialogue/boss_outro_solen_grief.json")

	# Solen death animation
	_solen.sprite.play("death")
	await _solen.sprite.animation_finished

	await get_tree().create_timer(1.5).timeout

	# Fade out Solen's body
	var solen_fade := create_tween()
	solen_fade.tween_property(_solen.sprite, "modulate:a", 0.0, 1.5)
	await solen_fade.finished
	var solen_pos: Vector2 = _solen.position
	_solen.queue_free()
	_solen = null

	# Mira and Ren — how do we get home?
	await _play_dialogue("res://data/dialogue/boss_outro_lost.json")

	# Camera shake — rift tremor
	await _camera_shake(0.6, 4.0)

	# Mysterious voice
	await _play_dialogue("res://data/dialogue/boss_outro_voice.json")

	# Spawn portal where Solen died
	var portal: AnimatedSprite2D = PORTAL_SCENE.instantiate()
	portal.position = solen_pos
	portal.z_index = 10
	portal.modulate.a = 0.0
	add_child(portal)
	portal.play("default")

	# Fade in the portal
	var portal_fade := create_tween()
	portal_fade.tween_property(portal, "modulate:a", 1.0, 1.5)
	await portal_fade.finished

	await get_tree().create_timer(2.0).timeout

	# Fade to white (stepping through portal)
	_overlay.color = Color(1, 1, 1, 0)
	var rift_flash := create_tween()
	rift_flash.tween_property(_overlay, "color:a", 1.0, 1.5)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await rift_flash.finished

	# Play portal video
	_play_portal_video()


func _play_portal_video() -> void:
	# Clear the scene and play the portal video fullscreen
	for child in get_children():
		child.queue_free()

	var video_layer := CanvasLayer.new()
	video_layer.layer = 100
	add_child(video_layer)

	var video_player := VideoStreamPlayer.new()
	video_player.stream = load("res://assets/Epilogue/Portal_video.ogv")
	video_player.anchor_left = 0.0
	video_player.anchor_top = 0.0
	video_player.anchor_right = 1.0
	video_player.anchor_bottom = 1.0
	video_player.expand = true
	video_layer.add_child(video_player)

	video_player.finished.connect(func() -> void:
		get_tree().change_scene_to_file(EPILOGUE_PATH)
	)
	video_player.play()
