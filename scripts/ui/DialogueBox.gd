extends CanvasLayer

const CHARS_PER_SEC := 35.0
var TYPING_SFX := preload("res://assets/Sounds/Typing sound effect.mp3")

var _full_text: String = ""
var _typing_player: AudioStreamPlayer
var _char_progress: float = 0.0
var _showing: bool = false
var _text_complete: bool = false

var _speaker_colors := {
	"Mira":  Color(0.2, 0.85, 0.7),
	"Ren":   Color(0.7, 0.5, 1.0),
	"Solen": Color(1.0, 0.85, 0.4),
	"Demon King": Color(0.9, 0.15, 0.15),
	"???": Color(0.6, 0.85, 1.0),
}

# --- Node references (set up in the DialogueBox.tscn scene file) ---
@onready var _panel: PanelContainer   = $Root/Panel
@onready var _speaker_label: Label     = $Root/Panel/VBox/SpeakerLabel
@onready var _text_label: RichTextLabel = $Root/Panel/VBox/TextLabel
@onready var _advance_arrow: Label     = $Root/Panel/VBox/AdvanceArrow


func _ready() -> void:
	_hide_box()
	_typing_player = AudioStreamPlayer.new()
	_typing_player.stream = TYPING_SFX
	if TYPING_SFX is AudioStreamMP3:
		TYPING_SFX.loop = true
	add_child(_typing_player)
	DialogueManager.line_ready.connect(_on_line)
	DialogueManager.dialogue_ended.connect(_on_end)
	DialogueManager.dialogue_started.connect(_on_start)


func _process(delta: float) -> void:
	if not _showing:
		return
	if not _text_complete:
		_char_progress += CHARS_PER_SEC * delta
		var count := int(_char_progress)
		if count >= _full_text.length():
			_text_label.text = _full_text
			_text_complete = true
			_advance_arrow.visible = true
			_typing_player.stop()
		else:
			_text_label.text = _full_text.substr(0, count)
	if _advance_arrow.visible:
		_advance_arrow.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)


func _unhandled_input(event: InputEvent) -> void:
	if not _showing:
		return
	
	if event.is_action_pressed("dialogue_advance"):
		if not _text_complete:
			_text_label.text = _full_text
			_text_complete = true
			_advance_arrow.visible = true
		else:
			DialogueManager.next_line()
		
		get_viewport().set_input_as_handled()


func _on_start() -> void:
	_panel.visible = true
	_showing = true


func _on_line(speaker: String, text: String) -> void:
	_speaker_label.text = speaker
	_speaker_label.add_theme_color_override("font_color",
		_speaker_colors.get(speaker, Color(0.9, 0.9, 0.9)))
	_full_text = text
	_char_progress = 0.0
	_text_complete = false
	_text_label.text = ""
	_advance_arrow.visible = false


func _on_end() -> void:
	_showing = false
	_hide_box()


func _hide_box() -> void:
	_panel.visible = false
	_showing = false
