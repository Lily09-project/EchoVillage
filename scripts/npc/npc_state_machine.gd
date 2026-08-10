class_name NPCStateMachine
extends RefCounted

const ACTION_TIMEOUT_MINUTES := 90
const ARRIVAL_DISTANCE := 8.0
const REQUIRED_STATES := ["Idle","Moving","PerformingAction","Talking","Sleeping","Working"]

func available_states() -> Array:
	return REQUIRED_STATES.duplicate()

func transition_for_action(npc: Dictionary, action_id: String, target: Vector2, minute: int) -> void:
	npc["current_action"] = action_id
	npc["current_target"] = target
	npc["target"] = target
	npc["state_entered_minute"] = minute
	npc["state"] = "Moving" if npc.get("position",Vector2.ZERO).distance_to(target) > ARRIVAL_DISTANCE else state_for_action(action_id)

func update(npc: Dictionary, minute: int) -> void:
	if minute - int(npc.get("state_entered_minute",minute)) >= ACTION_TIMEOUT_MINUTES:
		npc["state"] = "Idle"
		npc["current_action"] = "Idle"
		npc["current_goal"] = "Recover after action timeout"
		npc["state_entered_minute"] = minute
		return
	if str(npc.get("state","Idle")) == "Moving" and npc.get("position",Vector2.ZERO).distance_to(npc.get("current_target",npc.get("position",Vector2.ZERO))) <= ARRIVAL_DISTANCE:
		npc["state"] = state_for_action(str(npc.get("current_action","Idle")))
		npc["state_entered_minute"] = minute

func state_for_action(action_id: String) -> String:
	match action_id:
		"Sleep": return "Sleeping"
		"Work": return "Working"
		"Socialize": return "Talking"
		"Eat", "Shop", "Flee", "Help", "Rest", "Wander", "GoHome": return "PerformingAction"
	return "Idle"
