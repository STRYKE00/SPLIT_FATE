extends CanvasLayer

const MAX_HP := 5

@onready var _past_hp_bar: TextureRect = $Root/PastHPBar
@onready var _future_hp_bar: TextureRect = $Root/FutureHPBar
@onready var _sync_bar: ProgressBar = $Root/SyncBar
@onready var _boss_panel: VBoxContainer = $Root/BossPanel
@onready var _past_boss_bar: ProgressBar = $Root/BossPanel/PastBossBar
@onready var _future_boss_bar: ProgressBar = $Root/BossPanel/FutureBossBar
@onready var _past_text_banner: Label = $Root/PastTextLabel
@onready var _future_text_banner: Label = $Root/FutureTextLabel

var _mira_frames: Array[Texture2D] = []
var _ren_frames: Array[Texture2D] = []
var _banner: Label
var _banner_tween: Tween
var parent: Control
var BANNER_TOP_PADDING := 50


func _ready() -> void:
	for i in 6:
		_mira_frames.append(load("res://assets/ui/HP Bar/HP_MIRA/%d.png" % (35 + i)))
		_ren_frames.append(load("res://assets/ui/HP Bar/HP_REN/%d.png" % (41 + i)))
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
	_setup_viewport()
	

func _setup_viewport() -> void:
	parent = get_parent()
	if parent.name == "Main":
		await get_tree().process_frame
		await get_tree().process_frame

		var split_container: HBoxContainer = parent.get_node_or_null("SplitContainer")
		if split_container:
			var split_container_left: SubViewportContainer = split_container.get_node_or_null("LeftContainer")
			if split_container_left:
				_past_text_banner.global_position = split_container_left.global_position + Vector2(0, BANNER_TOP_PADDING)
				_past_text_banner.size = split_container_left.size
				_past_text_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_past_text_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

			var split_container_right: SubViewportContainer = split_container.get_node_or_null("RightContainer")
			if split_container_right:
				_future_text_banner.global_position = split_container_right.global_position + Vector2(0, BANNER_TOP_PADDING)
				_future_text_banner.size = split_container_right.size
				_future_text_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_future_text_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

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


func _on_boss_defeated(tl: String, _last_pos: Vector2 = Vector2.ZERO) -> void:
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
	s.hp_changed.connect(func(cur_hp: int, _max_hp: int): _update_hp_bar(_past_hp_bar, _mira_frames, cur_hp))
	_update_hp_bar(_past_hp_bar, _mira_frames, s.hp)


func connect_player_future(player: Node) -> void:
	var s: StatsComponent = player.stats
	s.hp_changed.connect(func(cur_hp: int, _max_hp: int): _update_hp_bar(_future_hp_bar, _ren_frames, cur_hp))
	_update_hp_bar(_future_hp_bar, _ren_frames, s.hp)


func _update_hp_bar(bar: TextureRect, frames: Array[Texture2D], hp: int) -> void:
	var frame_index: int = clampi(MAX_HP - hp, 0, 5)
	bar.texture = frames[frame_index]
