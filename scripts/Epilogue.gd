extends Node2D

# ── Constants ────────────────────────────────────────────────────────────────
const VIEWPORT_W    := 1376.0
const VIEWPORT_H    := 768.0
const CHARS_PER_SEC := 40.0
const CHAR_FADE_DUR := 0.8

const SPEAKER_COLORS := {
	"REN":  Color(0.7, 0.5, 1.0),
	"MIRA": Color(0.2, 0.85, 0.7),
}

const DIALOGUE := [
	{ "speaker": "",     "text": "They're home. Same rooftop. Same sunset. No memory of any of it — the rift, the timelines, the king. Just two people on a rooftop at the start of something.", "ren": 1, "mira": 1 },
	{ "speaker": "",     "text": "But Ren's hand finds Mira's without thinking. And she doesn't pull away.", "ren": 2, "mira": 2 },
	{ "speaker": "MIRA", "text": "You're humming something.", "ren": 2, "mira": 3 },
	{ "speaker": "REN",  "text": "Oh. I don't even know where I heard it.", "ren": 3, "mira": 3 },
	{ "speaker": "MIRA", "text": "I know that song. I don't know how, but I know it.", "ren": 3, "mira": 4 },
	{ "speaker": "",     "text": "A beat. Their hands are still intertwined. Neither mentions it. The city hums below them. Somewhere, very far away — the world they saved breathes on.", "ren": 4, "mira": 4 },
	{ "speaker": "REN",  "text": "Hey, Mira.", "ren": 5, "mira": 4 },
	{ "speaker": "MIRA", "text": "Mm?", "ren": 5, "mira": 5 },
	{ "speaker": "REN",  "text": "I don't know why — but I feel like I've been wanting to say this for longer than I actually have. I like you.", "ren": 6, "mira": 5 },
	{ "speaker": "MIRA", "text": "...I know. Me too. I've known for a while.", "ren": 6, "mira": 6 },
]

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _bg:            Sprite2D          = $BGLayer/BG
@onready var _ren:           Sprite2D          = $CharLayer/RenSprite
@onready var _mira:          Sprite2D          = $CharLayer/MiraSprite
@onready var _overlay:       ColorRect         = $UILayer/BlackOverlay
@onready var _panel:         PanelContainer    = $UILayer/DialoguePanel
@onready var _speaker_lbl:   Label             = $UILayer/DialoguePanel/VBox/SpeakerLabel
@onready var _text_lbl:      RichTextLabel     = $UILayer/DialoguePanel/VBox/DialogueText
@onready var _arrow:         Label             = $UILayer/DialoguePanel/VBox/AdvanceArrow
@onready var _music_player:  AudioStreamPlayer = $MusicPlayer
@onready var _typing_player: AudioStreamPlayer = $TypingPlayer

# ── Runtime state ─────────────────────────────────────────────────────────────
var _ren_textures:    Array  = []
var _mira_textures:   Array  = []
var _line_index:      int    = 0
var _char_progress:   float  = 0.0
var _text_complete:   bool   = false
var _dialogue_active: bool   = false
var _ending:          bool   = false


func _ready() -> void:
	_load_textures()
	_setup_audio()
	_overlay.color  = Color(0, 0, 0, 1)
	_panel.visible  = false
	_ren.modulate.a  = 0.0
	_mira.modulate.a = 0.0
	_arrow.visible   = false
	_setup_characters()
	_run_epilogue()

func _load_textures() -> void:
	_bg.texture = load("res://assets/Epilogue/Rooftop_Epilogue.jpg")
	for i in range(1, 7):
		_ren_textures.append(load("res://assets/Epilogue/Ren epilogue/%d.png" % i))
		_mira_textures.append(load("res://assets/Epilogue/Mira Prologue/%d.png" % i))
	_ren.texture  = _ren_textures[0]
	_mira.texture = _mira_textures[0]


func _setup_audio() -> void:
	var warm := load("res://assets/Sounds/Beautiful Japanese Music - Inu Sad Song Mix - Emotional Soundtrack.mp3") as AudioStreamMP3
	warm.loop = true
	_music_player.stream = warm

	var typing := load("res://assets/Sounds/Typing sound effect.mp3") as AudioStreamMP3
	typing.loop = true
	_typing_player.stream = typing


func _setup_characters() -> void:
	const SCALE     := 2.0
	const PANEL_TOP := 540.0
	_ren.scale  = Vector2(SCALE, SCALE)
	_mira.scale = Vector2(SCALE, SCALE)
	if _mira.texture:
		_mira.position = Vector2(250.0, PANEL_TOP - _mira.texture.get_height() * SCALE * 0.5)
	if _ren.texture:
		_ren.position = Vector2(1150.0, PANEL_TOP - _ren.texture.get_height() * SCALE * 0.5)


func _run_epilogue() -> void:
	_music_player.play()

	# Centre and scale background image to fill the screen
	_bg.position = Vector2(VIEWPORT_W * 0.5, VIEWPORT_H * 0.5)
	if _bg.texture:
		var tex_size := Vector2(_bg.texture.get_width(), _bg.texture.get_height())
		_bg.scale = Vector2(VIEWPORT_W / tex_size.x, VIEWPORT_H / tex_size.y)

	# Fade in from black
	var fade_in := create_tween()
	fade_in.tween_property(_overlay, "color:a", 0.0, 2.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await fade_in.finished

	await get_tree().create_timer(0.5).timeout

	# Characters fade in
	var chars_in := create_tween().set_parallel(true)
	chars_in.tween_property(_ren, "modulate:a", 1.0, CHAR_FADE_DUR).set_ease(Tween.EASE_OUT)
	chars_in.tween_property(_mira, "modulate:a", 1.0, CHAR_FADE_DUR).set_ease(Tween.EASE_OUT)
	await chars_in.finished

	await get_tree().create_timer(0.3).timeout

	# Begin dialogue
	_panel.visible   = true
	_dialogue_active = true
	_show_line(0)


func _show_line(idx: int) -> void:
	var entry:    Dictionary = DIALOGUE[idx]
	var speaker:  String     = entry["speaker"]
	var text:     String     = entry["text"]
	var ren_idx:  int        = int(entry["ren"]) - 1
	var mira_idx: int        = int(entry["mira"]) - 1

	# Swap character sprites
	_ren.texture  = _ren_textures[ren_idx]
	_mira.texture = _mira_textures[mira_idx]

	# Highlight the active speaker; dim the other
	match speaker:
		"REN":
			_ren.modulate  = Color(1.0, 1.0, 1.0, 1.0)
			_mira.modulate = Color(0.5, 0.5, 0.55, 0.75)
		"MIRA":
			_mira.modulate = Color(1.0, 1.0, 1.0, 1.0)
			_ren.modulate  = Color(0.5, 0.5, 0.55, 0.75)
		_:
			# Narration — both slightly dimmed
			_ren.modulate  = Color(0.85, 0.85, 0.88, 0.9)
			_mira.modulate = Color(0.85, 0.85, 0.88, 0.9)

	# Speaker name and colour
	_speaker_lbl.text = speaker
	var label_color: Color = SPEAKER_COLORS.get(speaker, Color(0.75, 0.72, 0.78, 0.65))
	_speaker_lbl.add_theme_color_override("font_color", label_color)

	# Narration is italicised
	if speaker.is_empty():
		_text_lbl.text = "[color=#b0a8c0][i]" + text + "[/i][/color]"
	else:
		_text_lbl.text = text

	_text_lbl.visible_characters = 0
	_char_progress = 0.0
	_text_complete = false
	_arrow.visible = false

	_typing_player.play()


func _process(delta: float) -> void:
	if _dialogue_active and not _text_complete:
		_char_progress += CHARS_PER_SEC * delta
		var count := int(_char_progress)
		var total := _text_lbl.get_total_character_count()
		if total > 0 and count >= total:
			_text_lbl.visible_characters = -1
			_typing_player.stop()
			_text_complete = true
			_arrow.visible = true
		elif total > 0:
			_text_lbl.visible_characters = count

	if _arrow.visible:
		_arrow.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)


func _unhandled_input(event: InputEvent) -> void:
	if _ending:
		return
	if not _dialogue_active:
		return

	if not event.is_action_pressed("dialogue_advance"):
		return

	get_viewport().set_input_as_handled()

	if not _text_complete:
		_typing_player.stop()
		_text_lbl.visible_characters = -1
		_text_complete = true
		_arrow.visible = true
		return

	# Advance to the next line
	_line_index += 1

	if _line_index >= DIALOGUE.size():
		_start_ending()
		return

	_show_line(_line_index)


func _start_ending() -> void:
	_ending          = true
	_dialogue_active = false
	_panel.visible   = false

	# Characters fade out
	var chars_out := create_tween().set_parallel(true)
	chars_out.tween_property(_ren, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	chars_out.tween_property(_mira, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)

	# Fade to black with music fade
	var fadeout := create_tween().set_parallel(true)
	fadeout.tween_property(_overlay, "color:a", 1.0, 2.0).set_ease(Tween.EASE_IN)
	fadeout.tween_property(_music_player, "volume_db", -80.0, 2.0)
	await fadeout.finished

	await get_tree().create_timer(1.5).timeout

	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
