extends CanvasLayer

const FRAME_W := 322
const FRAME_H := 129
const MAX_HP := 5

@onready var _past_hp_bar: TextureRect = $Root/PastHPBar
@onready var _future_hp_bar: TextureRect = $Root/FutureHPBar
@onready var _sync_bar: ProgressBar = $Root/SyncBar
@onready var _boss_panel: VBoxContainer = $Root/BossPanel
@onready var _past_boss_bar: ProgressBar = $Root/BossPanel/PastBossBar
@onready var _future_boss_bar: ProgressBar = $Root/BossPanel/FutureBossBar
@onready var _past_text_banner: Label = $Root/PastTextLabel
@onready var _future_text_banner: Label = $Root/FutureTextLabel

var _hp_bar_texture: Texture2D
var _banner: Label
var _banner_tween: Tween


func _ready() -> void:
	_hp_bar_texture = load("res://assets/ui/hp_bar.png")
	_sync_bar.max_value = TimelineManager.SYNC_MAX
	_sync_bar.value = TimelineManager.sync_value
	TimelineManager.sync_changed.connect(_on_sync_changed)
	TimelineManager.boss_spawned.connect(_on_boss_spawned)
	TimelineManager.boss_defeated.connect(_on_boss_defeated)
	TimelineManager.gear_collected.connect(_on_gear_collected)
	TimelineManager.tutorial_text.connect(_on_tutorial_text)
	TimelineManager.timeline_action.connect(_on_timeline_action)
	_boss_panel.visible = false
	_build_banner()

func _build_banner() -> void:
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.22
	_banner.anchor_bottom = 0.22
	_banner.offset_top = -48
	_banner.offset_bottom = 48
	_banner.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.modulate = Color(1, 1, 1, 0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_banner)


func _on_gear_collected(gear_id: String, timeline: String) -> void:
	var item_name: String = gear_id.capitalize()
	var side: String = "PAST" if timeline == "past" else "FUTURE"
	_show_banner("%s: %s Collected" % [side, item_name], 1.2, 24)
	
func _on_tutorial_text(tutorial_text: String, timeline: String) -> void:
	var label: Label = _past_text_banner if timeline == "past" else _future_text_banner
	_show_text_banner(label, tutorial_text, 2, 24)

func _show_text_banner(label: Label, text: String, hold: float, font_size: int) -> void:
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(hold)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
func _on_timeline_action(action_id: String, _src: String) -> void:
	if action_id == "area1_complete":
		_show_banner("AREA 1 COMPLETE", 2.4, 56)


func _show_banner(text: String, hold: float, font_size: int) -> void:
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.text = text
	_banner.add_theme_font_size_override("font_size", font_size)
	_banner.modulate = Color(1, 1, 1, 0)
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _on_boss_spawned(boss: Node) -> void:
	var bar: ProgressBar = _past_boss_bar if boss.timeline == "past" else _future_boss_bar
	bar.max_value = boss.stats.max_hp
	bar.value = boss.stats.hp
	boss.stats.hp_changed.connect(func(cur: int, _max: int): bar.value = cur)
	_boss_panel.visible = true


func _on_boss_defeated(tl: String) -> void:
	var bar: ProgressBar = _past_boss_bar if tl == "past" else _future_boss_bar
	bar.value = 0
	if _past_boss_bar.value <= 0 and _future_boss_bar.value <= 0:
		_boss_panel.visible = false


func _on_sync_changed(value: float) -> void:
	_sync_bar.value = value
	if value >= TimelineManager.SYNC_THRESHOLD:
		_sync_bar.modulate = Color(1.0, 0.85, 0.3, 1.0)
	else:
		_sync_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)


func connect_player_past(player: Node) -> void:
	var s: StatsComponent = player.stats
	s.hp_changed.connect(func(cur_hp: int, _max_hp: int): _update_hp_bar(_past_hp_bar, cur_hp))
	_update_hp_bar(_past_hp_bar, s.hp)


func connect_player_future(player: Node) -> void:
	var s: StatsComponent = player.stats
	s.hp_changed.connect(func(cur_hp: int, _max_hp: int): _update_hp_bar(_future_hp_bar, cur_hp))
	_update_hp_bar(_future_hp_bar, s.hp)


func _update_hp_bar(bar: TextureRect, hp: int) -> void:
	var frame_index: int = clampi(MAX_HP - hp, 0, 5)
	var atlas := AtlasTexture.new()
	atlas.atlas = _hp_bar_texture
	atlas.region = Rect2(0, frame_index * FRAME_H, FRAME_W, FRAME_H)
	bar.texture = atlas
