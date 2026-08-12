class_name ProgressionService
extends RefCounted

const TIERS := [
	{"index":0,"title":"陌生旅人","minimum":0,"next_minimum":5},
	{"index":1,"title":"熟悉面孔","minimum":5,"next_minimum":12},
	{"index":2,"title":"值得信賴","minimum":12,"next_minimum":25},
	{"index":3,"title":"村落支柱","minimum":25,"next_minimum":40},
	{"index":4,"title":"回音守望者","minimum":40,"next_minimum":40}
]

var definitions: Array = []

func _init(achievement_definitions: Array = []) -> void:
	definitions = achievement_definitions.duplicate(true)

func default_state() -> Dictionary:
	return {"unlocked_ids":[],"unlocked_at":{},"stats":{"interactions":0,"trades":0}}

func reputation_tier(renown: int) -> Dictionary:
	var safe_renown := maxi(0,renown)
	var selected: Dictionary = TIERS[0]
	for tier in TIERS:
		if safe_renown >= int(tier["minimum"]): selected = tier
	return selected.duplicate(true)

func evaluate(state: Dictionary, snapshot: Dictionary) -> Dictionary:
	var next_state: Dictionary = _normalize_state(state)
	var unlocked: Array = []
	for value in definitions:
		if not (value is Dictionary): continue
		var definition: Dictionary = value
		var achievement_id := str(definition.get("id",""))
		if achievement_id == "" or achievement_id in next_state["unlocked_ids"]: continue
		if _condition_met(definition.get("condition",{}),snapshot):
			next_state["unlocked_ids"].append(achievement_id)
			next_state["unlocked_at"][achievement_id] = str(snapshot.get("timestamp",""))
			unlocked.append(definition.duplicate(true))
	return {"state":next_state,"unlocked":unlocked}

func _normalize_state(state: Dictionary) -> Dictionary:
	var result := default_state()
	if state.get("unlocked_ids",[]) is Array: result["unlocked_ids"] = state["unlocked_ids"].duplicate(true)
	if state.get("unlocked_at",{}) is Dictionary: result["unlocked_at"] = state["unlocked_at"].duplicate(true)
	if state.get("stats",{}) is Dictionary:
		for key in state["stats"]: result["stats"][str(key)] = maxi(0,int(state["stats"][key]))
	return result

func _condition_met(condition_value, snapshot: Dictionary) -> bool:
	if not (condition_value is Dictionary): return false
	var condition: Dictionary = condition_value
	var kind := str(condition.get("type",""))
	var key := str(condition.get("key",""))
	var target := int(condition.get("value",1))
	match kind:
		"renown_at_least": return int(snapshot.get("renown",0)) >= target
		"stat_at_least": return int(snapshot.get("stats",{}).get(key,0)) >= target
		"community_flag": return bool(snapshot.get("community_flags",{}).get(key,false))
		"quest_completed": return key in snapshot.get("completed_quests",[])
		"world_flag_at_least": return int(snapshot.get("world_flags",{}).get(key,0)) >= target
	return false
