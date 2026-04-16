extends PlayerBase


func _ready() -> void:
	timeline = "future"
	action_left    = "future_left"
	action_right   = "future_right"
	action_up      = "future_up"
	action_down    = "future_down"
	action_attack  = "future_attack"
	action_heavy   = "future_heavy"
	action_interact = "future_interact"
	action_dash    = "future_dash"
	slash_color = Color(0.7, 0.5, 1.0)
	super._ready()
