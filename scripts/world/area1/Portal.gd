extends Node

const PLAYER_LAYER := 2
const FADE_TIME := 0.8

var past_world: Node2D
var future_world: Node2D
var past_overlay: ColorRect
var future_overlay: ColorRect
var past_player: PlayerBase
var future_player: PlayerBase

var _past_finished: bool = false
var _future_finished: bool = false

signal both_portals_reached


func setup(p_past_world: Node2D, p_future_world: Node2D, p_past_overlay: ColorRect, p_future_overlay: ColorRect, p_past_player: PlayerBase, p_future_player: PlayerBase) -> void:
	past_world = p_past_world
	future_world = p_future_world
	past_overlay = p_past_overlay
	future_overlay = p_future_overlay
	past_player = p_past_player
	future_player = p_future_player

	_attach_trigger("past", Vector2(-1824, 1848), past_world)
	_attach_trigger("future", Vector2(-2016, 1920), future_world)


func _attach_trigger(timeline: String, pos: Vector2, world: Node2D) -> void:
	var trigger := Area2D.new()
	trigger.name = "PortalTrigger_%s" % timeline
	trigger.position = pos
	trigger.collision_layer = 0
	trigger.collision_mask = PLAYER_LAYER

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	col.shape = circle
	trigger.add_child(col)

	trigger.body_entered.connect(func(body: Node2D):
		if not body.is_in_group("players"):
			return
		_on_portal_entered(timeline, trigger)
	)
	world.add_child(trigger)


func _on_portal_entered(timeline: String, trigger: Area2D) -> void:
	trigger.monitoring = false

	if timeline == "past":
		if _past_finished:
			return
		_past_finished = true
		_freeze_player(past_player)
		_fade_side(past_overlay)
	else:
		if _future_finished:
			return
		_future_finished = true
		_freeze_player(future_player)
		_fade_side(future_overlay)

	if _past_finished and _future_finished:
		await get_tree().create_timer(0.5).timeout
		_send_to_boss()


func _freeze_player(player: PlayerBase) -> void:
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO


func _fade_side(overlay: ColorRect) -> void:
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", 1.0, FADE_TIME)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


func _send_to_boss() -> void:
	GameState.is_transitioning = true

	GameState.past_player_hp = past_player.stats.hp
	GameState.future_player_hp = future_player.stats.hp

	var tw := create_tween().set_parallel(true)
	tw.tween_property(past_overlay, "color:a", 1.0, 0.4)
	tw.tween_property(future_overlay, "color:a", 1.0, 0.4)
	await tw.finished

	both_portals_reached.emit()
