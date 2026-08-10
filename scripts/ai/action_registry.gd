class_name ActionRegistry
extends RefCounted

const ORDER := ["Eat","Sleep","Work","Socialize","Wander","Shop","GoHome","Flee","Help","Rest"]
const ACTION_SCRIPTS := {
	"Eat":preload("res://scripts/actions/eat_action.gd"),
	"Sleep":preload("res://scripts/actions/sleep_action.gd"),
	"Work":preload("res://scripts/actions/work_action.gd"),
	"Socialize":preload("res://scripts/actions/socialize_action.gd"),
	"Wander":preload("res://scripts/actions/wander_action.gd"),
	"Shop":preload("res://scripts/actions/shop_action.gd"),
	"GoHome":preload("res://scripts/actions/go_home_action.gd"),
	"Flee":preload("res://scripts/actions/flee_action.gd"),
	"Help":preload("res://scripts/actions/help_action.gd"),
	"Rest":preload("res://scripts/actions/rest_action.gd")
}
var actions: Dictionary = {}

func _init() -> void:
	for action_id in ORDER:
		actions[action_id] = ACTION_SCRIPTS[action_id].new()

func action_ids() -> Array:
	return ORDER.duplicate()

func get_action(action_id: String):
	return actions.get(action_id)

func calculate_scores(npc: Dictionary, context: Dictionary) -> Dictionary:
	var scores := {}
	for action_id in ORDER:
		var action = actions[action_id]
		var cooldowns: Dictionary = context.get("action_cooldowns",{})
		var on_cooldown := int(cooldowns.get(action_id,-1)) > int(context.get("minute",0))
		scores[action_id] = action.calculate_score(npc,context) if action.can_execute(npc,context) and not on_cooldown else -1000.0
	return scores
