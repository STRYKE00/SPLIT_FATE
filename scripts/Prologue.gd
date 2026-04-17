extends Node2D

# ── Constants ────────────────────────────────────────────────────────────────
const VIEWPORT_W    := 1376.0
const VIEWPORT_H    := 768.0
const CHARS_PER_SEC := 40.0
const PAN_DURATION  := 4.5
const CHAR_FADE_DUR := 0.8
const RIFT_LINE_IDX := 6   # index of the "rift tears open" narration line

const SPEAKER_COLORS := {
	"REN":  Color(0.7, 0.5, 1.0),
	"MIRA": Color(0.2, 0.85, 0.7),
}

const DIALOGUE := [
	{ "speaker": "REN",  "text": "You know what's stupid? I've been rehearsing this for like three years. Three years. And now I can't remember a single word.", "ren": 1, "mira": 1 },
	{ "speaker": "MIRA", "text": "Then don't say it. Just... say the actual thing.", "ren": 1, "mira": 2 },
	{ "speaker": "REN",  "text": "I like you. I've liked you since you cried at that movie about the dog and then immediately said you weren't crying.", "ren": 2, "mira": 2 },
	{ "speaker": "MIRA", "text": "That dog deserved better and you know it.", "ren": 2, "mira": 3 },
	{ "speaker": "REN",  "text": "Mira.", "ren": 2, "mira": 3 },
	{ "speaker": "MIRA", "text": "...I know. Me too. I've known for a while.", "ren": 3, "mira": 2 },
	{ "speaker": "",     "text": "A long, warm silence. She leans her head on his shoulder. The sky cracks open — a blinding rift tears through the air above them.", "ren": 4, "mira": 6 },
	{ "speaker": "MIRA", "text": "Ren — what is—", "ren": 5, "mira": 5 },
	{ "speaker": "REN",  "text": "MIRA—", "ren": 6, "mira": 6 },
	{ "speaker": "",     "text": "The rift pulls them in. Their hands reach for each other — and miss by an inch.", "ren": 6, "mira": 4 },
]

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _bg:             Sprite2D          = $BGLayer/BG
@onready var _ren:            Sprite2D          = $CharLayer/RenSprite
@onready var _mira:           Sprite2D          = $CharLayer/MiraSprite
@onready var _overlay:        ColorRect         = $UILayer/BlackOverlay
@onready var _rift_flash:     ColorRect         = $UILayer/RiftFlash
@onready var _panel:          PanelContainer    = $UILayer/DialoguePanel
@onready var _speaker_lbl:    Label             = $UILayer/DialoguePanel/VBox/SpeakerLabel
@onready var _text_lbl:       RichTextLabel     = $UILayer/DialoguePanel/VBox/DialogueText
@onready var _arrow:          Label             = $UILayer/DialoguePanel/VBox/AdvanceArrow
@onready var _music_player:   AudioStreamPlayer = $MusicPlayer
@onready var _shocked_player: AudioStreamPlayer = $ShockedPlayer
@onready var _typing_player:  AudioStreamPlayer = $TypingPlayer
@onready var _skip_btn:       Button            = $UILayer/SkipButton

# ── Runtime state ─────────────────────────────────────────────────────────────
var _ren_textures:     Array             = []
var _mira_textures:    Array             = []
var _thriller_stream:  AudioStreamMP3    = null
var _line_index:       int               = 0
var _char_progress:    float             = 0.0
var _text_complete:    bool              = false
var _dialogue_active:  bool              = false
var _ending:           bool              = false
var _transitioning:    bool              = false


func _ready() -> void:
	_load_textures()
	_setup_audio()
	_overlay.color    = Color(0, 0, 0, 1)
	_rift_flash.color = Color(1, 1, 1, 0)
	_panel.visible    = false
	_ren.modulate.a   = 0.0
	_mira.modulate.a  = 0.0
	_arrow.visible    = false
	_setup_characters()
	_skip_btn.pressed.connect(_on_skip_pressed)
	_run_prologue()


func _load_textures() -> void:
	_bg.texture = load("res://assets/PROLOGUE/PROLOGUE BG.png")
	for i in range(1, 7):
		_ren_textures.append(load("res://assets/PROLOGUE/REN PROLOGUE/%d.png" % i))
		_mira_textures.append(load("res://assets/PROLOGUE/MIRA PROLOGUE/%d.png" % i))
	_ren.texture  = _ren_textures[0]
	_mira.texture = _mira_textures[0]


func _setup_audio() -> void:
	var warm := load("res://assets/Sounds/Warm music.mp3") as AudioStreamMP3
	warm.loop = true
	_music_player.stream = warm

	var shocked := load("res://assets/Sounds/Shocked sound Effect.mp3") as AudioStreamMP3
	_shocked_player.stream = shocked

	_thriller_stream = load("res://assets/Sounds/Thriller music.mp3") as AudioStreamMP3
	_thriller_stream.loop = true

	var typing := load("res://assets/Sounds/Typing sound effect.mp3") as AudioStreamMP3
	typing.loop = true
	_typing_player.stream = typing


func _setup_characters() -> void:
	# Bottom of sprites flush with the top of the dialogue panel (y=510)
	const SCALE     := 2.0
	const PANEL_TOP := 540.0
	_ren.scale  = Vector2(SCALE, SCALE)
	_mira.scale = Vector2(SCALE, SCALE)
	# Mira left, Ren right
	if _mira.texture:
		_mira.position = Vector2(250.0,  PANEL_TOP - _mira.texture.get_height() * SCALE * 0.5)
	if _ren.texture:
		_ren.position  = Vector2(1150.0, PANEL_TOP - _ren.texture.get_height()  * SCALE * 0.5)


func _run_prologue() -> void:
	# ── Start warm music ──────────────────────────────────────────────────
	_music_player.play()

	# ── BG pan: start at top of image, tween down to bottom ──────────────
	var bg_h      := float(_bg.texture.get_height()) if _bg.texture else VIEWPORT_H
	var wait_time := PAN_DURATION - 0.5

	if bg_h > VIEWPORT_H:
		# start_y = bg_h/2  → top of texture aligns with top of screen
		# end_y   = VIEWPORT_H - bg_h/2  → bottom of texture aligns with bottom of screen
		_bg.position = Vector2(VIEWPORT_W * 0.5, bg_h * 0.5)
		var pan := create_tween()
		pan.tween_property(_bg, "position:y", VIEWPORT_H - bg_h * 0.5, PAN_DURATION) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	else:
		_bg.position = Vector2(VIEWPORT_W * 0.5, VIEWPORT_H * 0.5)
		wait_time = 1.2

	# ── Fade in from black (concurrent with pan) ──────────────────────────
	var fade_in := create_tween()
	fade_in.tween_property(_overlay, "color:a", 0.0, 1.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	# Wait until near the end of the pan before showing characters
	await get_tree().create_timer(wait_time).timeout

	# ── Characters fade in ────────────────────────────────────────────────
	var chars_in := create_tween().set_parallel(true)
	chars_in.tween_property(_ren,  "modulate:a", 1.0, CHAR_FADE_DUR).set_ease(Tween.EASE_OUT)
	chars_in.tween_property(_mira, "modulate:a", 1.0, CHAR_FADE_DUR).set_ease(Tween.EASE_OUT)
	await chars_in.finished

	await get_tree().create_timer(0.3).timeout

	# ── Begin dialogue ────────────────────────────────────────────────────
	_panel.visible   = true
	_dialogue_active = true
	_show_line(0)


func _show_line(idx: int) -> void:
	var entry    : Dictionary = DIALOGUE[idx]
	var speaker  : String     = entry["speaker"]
	var text     : String     = entry["text"]
	var ren_idx  : int        = int(entry["ren"])  - 1
	var mira_idx : int        = int(entry["mira"]) - 1

	# Stop warm music the moment the rift narration line appears
	if idx == RIFT_LINE_IDX:
		_music_player.stop()

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

	# Narration is italicised and slightly muted via BBCode
	if speaker.is_empty():
		_text_lbl.text = "[color=#b0a8c0][i]" + text + "[/i][/color]"
	else:
		_text_lbl.text = text

	_text_lbl.visible_characters = 0
	_char_progress = 0.0
	_text_complete = false
	_arrow.visible = false

	# Start typing sound for every new line
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
	if _ending or _transitioning:
		return
	if not _dialogue_active:
		return

	if not event.is_action_pressed("dialogue_advance"):
		return

	get_viewport().set_input_as_handled()

	if not _text_complete:
		# Skip typewriter — reveal full line immediately
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

	# White rift flash when leaving the "sky cracks open" narration line
	if _line_index == RIFT_LINE_IDX + 1:
		_transitioning   = true
		_dialogue_active = false
		_do_rift_flash()
	else:
		_show_line(_line_index)


func _do_rift_flash() -> void:
	# Fire shocked SFX (warm music already stopped when the rift line appeared)
	_shocked_player.play()

	# Quick white flash — the rift tears open
	var flash := create_tween()
	flash.tween_property(_rift_flash, "color:a", 0.85, 0.10).set_ease(Tween.EASE_OUT)
	flash.tween_property(_rift_flash, "color:a", 0.0,  0.40).set_ease(Tween.EASE_IN)
	await flash.finished

	# Switch to thriller music
	_music_player.stream = _thriller_stream
	_music_player.play()

	_transitioning   = false
	_dialogue_active = true
	_show_line(_line_index)


func _on_skip_pressed() -> void:
	if _ending or _transitioning:
		return
	_ending          = true
	_dialogue_active = false
	_music_player.stop()
	_shocked_player.stop()
	_typing_player.stop()
	_skip_btn.visible = false
	var fade := create_tween()
	fade.tween_property(_overlay, "color:a", 1.0, 0.4).set_ease(Tween.EASE_IN)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _start_ending() -> void:
	_ending          = true
	_dialogue_active = false
	_panel.visible   = false

	# Characters fade out as the rift swallows them
	var chars_out := create_tween().set_parallel(true)
	chars_out.tween_property(_ren,  "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	chars_out.tween_property(_mira, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)

	# Rift crescendo — white engulfs the screen
	var flash := create_tween()
	flash.tween_property(_rift_flash, "color:a", 1.0, 0.8).set_ease(Tween.EASE_IN)
	await flash.finished

	await get_tree().create_timer(0.25).timeout

	# Cross-fade from blinding white into black; fade thriller music out with it
	var fadeout := create_tween().set_parallel(true)
	fadeout.tween_property(_overlay,      "color:a",   1.0,   1.1).set_ease(Tween.EASE_IN)
	fadeout.tween_property(_rift_flash,   "color:a",   0.0,   0.9).set_ease(Tween.EASE_IN)
	fadeout.tween_property(_music_player, "volume_db", -80.0, 1.0)
	await fadeout.finished

	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
