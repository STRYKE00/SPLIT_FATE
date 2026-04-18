extends CanvasLayer

const PLAYER_MAX_HP := 5

@onready var _root: Control = $Root
@onready var _panel: Control = $Root/BossPanel
@onready var _label: Label = $Root/BossPanel/VBox/Label
@onready var _bar: ProgressBar = $Root/BossPanel/VBox/ProgressBar
@onready var _past_hp_bar: TextureRect = $Root/PastHPBar
@onready var _future_hp_bar: TextureRect = $Root/FutureHPBar

var _mira_frames: Array[Texture2D] = []
var _ren_frames: Array[Texture2D] = []


func _ready() -> void:
	for i in 6:
		_mira_frames.append(load("res://assets/ui/HP Bar/HP_MIRA/%d.png" % (35 + i)))
		_ren_frames.append(load("res://assets/ui/HP Bar/HP_REN/%d.png" % (41 + i)))
	_panel.visible = false
	_panel.modulate.a = 1.0

	TimelineManager.boss_spawned.connect(_on_boss_spawned)
	TimelineManager.boss_hp_changed.connect(_on_hp_changed)
	TimelineManager.boss_defeated.connect(_on_boss_defeated)

	var existing := get_tree().get_nodes_in_group("bosses")
	if existing.size() > 0:
		_on_boss_spawned(existing[0])


func _on_boss_spawned(boss: Node) -> void:
	var max_hp: int = boss.stats.max_hp if boss and boss.stats else int(_bar.max_value)
	_panel.visible = true
	_panel.modulate.a = 1.0
	_bar.max_value = max_hp
	_bar.value = boss.stats.hp if boss and boss.stats else max_hp
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.05, 1.0)
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_hp_changed(current: int, max_hp: int) -> void:
	_bar.max_value = max_hp
	var tw := create_tween()
	tw.tween_property(_bar, "value", current, 0.2)


func _on_boss_defeated(_timeline: String, _last_pos: Vector2 = Vector2.ZERO) -> void:
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _panel.visible = false)


func connect_player_past(player: Node) -> void:
	var s: StatsComponent = player.stats
	s.hp_changed.connect(func(cur_hp: int, _max_hp: int): _update_hp_bar(_past_hp_bar, _mira_frames, cur_hp))
	_update_hp_bar(_past_hp_bar, _mira_frames, s.hp)


func connect_player_future(player: Node) -> void:
	var s: StatsComponent = player.stats
	s.hp_changed.connect(func(cur_hp: int, _max_hp: int): _update_hp_bar(_future_hp_bar, _ren_frames, cur_hp))
	_update_hp_bar(_future_hp_bar, _ren_frames, s.hp)


func _update_hp_bar(bar: TextureRect, frames: Array[Texture2D], hp: int) -> void:
	var frame_index: int = clampi(PLAYER_MAX_HP - hp, 0, 5)
	bar.texture = frames[frame_index]
