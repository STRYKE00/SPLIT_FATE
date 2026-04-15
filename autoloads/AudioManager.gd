extends Node

var _bgm: AudioStreamPlayer
var _sfx: AudioStreamPlayer


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "Master"
	add_child(_bgm)

	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Master"
	add_child(_sfx)


func play_bgm(stream: AudioStream, fade_in: float = 1.0) -> void:
	if _bgm.playing:
		var tw := create_tween()
		tw.tween_property(_bgm, "volume_db", -40.0, 0.3)
		await tw.finished
		_bgm.stop()
	_bgm.stream = stream
	_bgm.volume_db = -40.0
	_bgm.play()
	var tw := create_tween()
	tw.tween_property(_bgm, "volume_db", 0.0, fade_in)


func stop_bgm(fade_out: float = 1.0) -> void:
	if not _bgm.playing:
		return
	var tw := create_tween()
	tw.tween_property(_bgm, "volume_db", -40.0, fade_out)
	await tw.finished
	_bgm.stop()


func play_sfx(stream: AudioStream, volume: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
