class_name Solen
extends CharacterBody2D

enum STATE {
	IDLE_PAST,
	IDLE_FUTURE,
	TALK,
	TURN_AWAY,
	URGENT_BOSS
}

var state: STATE = STATE.IDLE_PAST
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_playback: AnimationNodeStateMachinePlayback = $AnimationTree["parameters/playback"]


func _ready()->void:
	animation_tree.active = true
	update_animation()

func _physics_process(delta: float) -> void:
	move_and_slide()
	
func update_animation()->void:
	match state:
		STATE.IDLE_PAST:
			animation_playback.start("idle_before")
		STATE.IDLE_FUTURE:
			animation_playback.start("idle_after")
		STATE.TALK:
			animation_playback.travel("talk")
		STATE.TURN_AWAY:
			animation_playback.travel("turn_away")
		STATE.URGENT_BOSS:
			animation_playback.travel("urgent_boss")
			
func set_state(new_state: STATE)-> void:
	if state==new_state:
		return
		
	state = new_state
	update_animation()
	
