extends Control

const SCROLL_SPEED := 35.0
const FADE_DURATION := 1.2

const COL_GOLD     := Color(0.96, 0.78, 0.26)
const COL_SILVER   := Color(0.75, 0.78, 0.88)
const COL_SOFT     := Color(0.88, 0.85, 0.95)
const COL_DIM      := Color(0.45, 0.42, 0.55)
const COL_HEADING  := Color(0.55, 0.82, 1.0)
const COL_BG       := Color(0.04, 0.03, 0.08)

const CREDITS_DATA := [
	{"type": "spacer", "h": 80},

	{"type": "title", "text": "S P L I T   F A T E", "size": 40},
	{"type": "subtitle", "text": "Echoes of Time", "size": 20},
	{"type": "spacer", "h": 50},

	{"type": "heading", "text": "--- AI-GENERATED ASSETS ---"},
	{"type": "body", "text": "Characters & Scenes"},
	{"type": "list", "items": ["Mira", "Ren", "Solen", "Demon King", "Epilogue Scene", "Prologue Scene", "Rift", "Bridge (Past)", "Bridge (Future)"]},
	{"type": "spacer", "h": 6},
	{"type": "body", "text": "UI Elements"},
	{"type": "list", "items": ["HP Bar UI", "Background", "Play Button", "Credits Button"]},
	{"type": "spacer", "h": 40},

	{"type": "heading", "text": "--- ENVIRONMENT ART ---"},
	{"type": "credit", "role": "Dungeon Forest", "name": "ZedPxl"},
	{"type": "credit", "role": "Dungeon RPG Tileset", "name": "Rekkimaru"},
	{"type": "credit", "role": "Village / Outside Houses", "name": "ZedPxl"},
	{"type": "credit", "role": "Sunnyside Free Tiles", "name": "Daniel Diggle"},
	{"type": "credit", "role": "Top-Down Pixel Dungeon", "name": "CraftPix.net"},
	{"type": "spacer", "h": 40},

	{"type": "heading", "text": "--- CHARACTER ART ---"},
	{"type": "credit", "role": "Enemy Sprites", "name": "Zerie"},
	{"type": "spacer", "h": 40},

	{"type": "heading", "text": "--- MUSIC & SOUND ---"},
	{"type": "credit", "role": "Main Menu Theme", "name": "Gate of Vortalania"},
	{"type": "credit", "role": "Medieval Music", "name": "Brandon Fiechter's Music"},
	{"type": "credit", "role": "Thriller Music", "name": "Cold Cinema"},
	{"type": "credit", "role": "Boss Room Sound", "name": "RPG Sountracks"},
	{"type": "credit", "role": "Warm / Calm Music", "name": "Umbr Tone"},
	{"type": "credit", "role": "Epilogue Music", "name": "Soul of the Wind"},
	{"type": "credit", "role": "Victory Fanfare", "name": "Breaking Copyright"},
	{"type": "credit", "role": "Shocked Sound Effect", "name": "Trivia King"},
	{"type": "spacer", "h": 40},

	{"type": "heading", "text": "--- TOOLS & ENGINE ---"},
	{"type": "credit", "role": "Game Engine", "name": "Godot 4"},
	{"type": "credit", "role": "AI Art Generation", "name": "Claude (Anthropic), Gemini , Afwan"},
	{"type": "spacer", "h": 60},

	{"type": "divider"},
	{"type": "spacer", "h": 20},
	{"type": "thanks", "text": "Thank you for playing."},
	{"type": "subtitle", "text": "Every echo leaves a trace.", "size": 16},
	{"type": "spacer", "h": 40},
	{"type": "dim", "text": "SPLIT FATE TEAM"},
	{"type": "spacer", "h": 8},
	{"type": "fine", "text": "2025 - All licensed assets remain property of their respective creators."},
	{"type": "spacer", "h": 500},
]

@onready var overlay: ColorRect = $CanvasLayer/BlackOverlay
@onready var back_btn: Button = $CanvasLayer/BackButton

var _content: VBoxContainer
var _scroll_offset := 0.0
var _auto_scroll := true
var _stars: Array[Dictionary] = []


func _ready() -> void:
	overlay.color.a = 1.0

	var stream := load("res://assets/ui/main_menu_music.mp3") as AudioStreamMP3
	stream.loop = true
	AudioManager.play_bgm(stream)

	for i in 100:
		_stars.append({
			"pos": Vector2(randf() * 1376, randf() * 768),
			"base_alpha": randf_range(0.15, 0.5),
			"speed": randf_range(0.8, 2.5),
			"phase": randf() * TAU,
		})

	_build_credits()

	var fade := create_tween()
	fade.tween_property(overlay, "color:a", 0.0, FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	back_btn.pressed.connect(_on_back_pressed)


func _build_credits() -> void:
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.custom_minimum_size.x = 600
	_content.add_theme_constant_override("separation", 4)
	_content.position = Vector2((1376 - 600) / 2.0, 0)
	add_child(_content)

	for entry in CREDITS_DATA:
		match entry["type"]:
			"spacer":
				var s := Control.new()
				s.custom_minimum_size.y = entry["h"]
				_content.add_child(s)

			"title":
				var lbl := _make_label(entry["text"], entry["size"], COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
				_content.add_child(lbl)

			"subtitle":
				var lbl := _make_label(entry["text"], entry["size"], COL_SILVER, HORIZONTAL_ALIGNMENT_CENTER)
				_content.add_child(lbl)

			"heading":
				var pad := Control.new()
				pad.custom_minimum_size.y = 4
				_content.add_child(pad)
				var lbl := _make_label(entry["text"], 18, COL_HEADING, HORIZONTAL_ALIGNMENT_CENTER)
				_content.add_child(lbl)
				var pad2 := Control.new()
				pad2.custom_minimum_size.y = 8
				_content.add_child(pad2)

			"body":
				var lbl := _make_label(entry["text"], 15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT)
				_content.add_child(lbl)

			"list":
				var line := ""
				for item in entry["items"]:
					if line != "":
						line += "   /   "
					line += item
				var lbl := _make_label(line, 16, COL_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
				lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_content.add_child(lbl)

			"credit":
				var row := HBoxContainer.new()
				row.add_child(_make_label(entry["role"], 17, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
				var dots := Label.new()
				dots.text = "  ......  "
				dots.add_theme_color_override("font_color", Color(1, 1, 1, 0.1))
				dots.add_theme_font_size_override("font_size", 14)
				dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				row.add_child(dots)
				row.add_child(_make_label(entry["name"], 17, COL_SOFT, HORIZONTAL_ALIGNMENT_RIGHT))
				_content.add_child(row)

			"divider":
				var lbl := _make_label("- - - - - - - - -", 14, Color(1, 1, 1, 0.15), HORIZONTAL_ALIGNMENT_CENTER)
				_content.add_child(lbl)

			"thanks":
				var lbl := _make_label(entry["text"], 24, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
				_content.add_child(lbl)

			"dim":
				var lbl := _make_label(entry["text"], 13, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER)
				_content.add_child(lbl)

			"fine":
				var lbl := _make_label(entry["text"], 10, Color(1, 1, 1, 0.12), HORIZONTAL_ALIGNMENT_CENTER)
				_content.add_child(lbl)


func _make_label(text: String, size: int, color: Color, align: HorizontalAlignment, expand := false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = align
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _process(delta: float) -> void:
	if _auto_scroll:
		_scroll_offset += SCROLL_SPEED * delta
		_content.position.y = -_scroll_offset + 768

		var max_scroll := _content.size.y
		if _scroll_offset >= max_scroll:
			_auto_scroll = false

	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for s in _stars:
		var a: float = s["base_alpha"] + sin(t * s["speed"] + s["phase"]) * 0.3
		a = clampf(a, 0.05, 0.9)
		draw_rect(Rect2(s["pos"], Vector2(2, 2)), Color(1, 1, 1, a))


func _on_back_pressed() -> void:
	back_btn.disabled = true
	var fade := create_tween()
	fade.tween_property(overlay, "color:a", 1.0, 0.6)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await fade.finished
	AudioManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
