extends PlayerBase


func _ready() -> void:
	timeline = "past"
	action_left    = "past_left"
	action_right   = "past_right"
	action_up      = "past_up"
	action_down    = "past_down"
	action_attack  = "past_attack"
	action_interact = "past_interact"
	action_dash    = "past_dash"
	slash_color = Color(0.2, 0.85, 0.7)
	super._ready()
	sprite.modulate = Color(0.35, 0.9, 0.75)
