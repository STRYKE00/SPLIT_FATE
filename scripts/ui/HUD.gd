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

var _hp_bar_texture: Texture2D


func _ready() -> void:
	_hp_bar_texture = load("res://assets/ui/hp_bar.png")
	_sync_bar.max_value = TimelineManager.SYNC_MAX
	_sync_bar.value = TimelineManager.sync_value
	TimelineManager.sync_changed.connect(_on_sync_changed)
	TimelineManager.boss_spawned.connect(_on_boss_spawned)
	TimelineManager.boss_defeated.connect(_on_boss_defeated)
	_boss_panel.visible = false


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
