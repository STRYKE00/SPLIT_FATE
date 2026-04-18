extends Node

# Toggles fullscreen on F11.
# Consumes the event so it never leaks to gameplay input.

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_F11:
		return

	var current := DisplayServer.window_get_mode()
	if current == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	get_viewport().set_input_as_handled()
