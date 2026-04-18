extends CanvasLayer

const FRAME_W := 322
const FRAME_H := 129
const PLAYER_MAX_HP := 5

@onready var _root: Control = $Root
@onready var _panel: Control = $Root/BossPanel
@onready var _label: Label = $Root/BossPanel/VBox/Label
@onready var _bar: ProgressBar = $Root/BossPanel/VBox/ProgressBar
@onready var _past_hp_bar: TextureRect = $Root/PastHPBar
@onready var _future_hp_bar: TextureRect = $Root/FutureHPBar

var _hp_bar_texture: Texture2D


func _ready() -> void:
	_hp_bar_texture = load("res://assets/ui/hp_bar.png")
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
	s.hp_changed.connect(func(cur_hp: int, _max_hp: int): _update_hp_bar(_past_hp_bar, cur_hp))
	_update_hp_bar(_past_hp_bar, s.hp)


func connect_player_future(player: Node) -> void:
	var s: StatsComponent = player.stats
	s.hp_changed.connect(func(cur_hp: int, _max_hp: int): _update_hp_bar(_future_hp_bar, cur_hp))
	_update_hp_bar(_future_hp_bar, s.hp)


func _update_hp_bar(bar: TextureRect, hp: int) -> void:
	var frame_index: int = clampi(PLAYER_MAX_HP - hp, 0, 5)
	var atlas := AtlasTexture.new()
	atlas.atlas = _hp_bar_texture
	atlas.region = Rect2(0, frame_index * FRAME_H, FRAME_W, FRAME_H)
	bar.texture = atlas
