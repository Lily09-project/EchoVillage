class_name WorldState
extends RefCounted

static func expansion_defaults() -> Dictionary:
	return {
		"current_location":"village_square",
		"discovered_locations":["village_square"],
		"active_quests":{},
		"completed_quests":[],
		"world_flags":{},
		"progression":{"unlocked_ids":[],"unlocked_at":{},"stats":{"interactions":0,"trades":0}}
	}
