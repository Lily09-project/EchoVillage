class_name SaveMigration
extends RefCounted

const WorldStateData = preload("res://scripts/core/world_state.gd")

static func migrate(envelope: Dictionary) -> Dictionary:
	var version := int(envelope.get("save_version",1))
	if version > 2: return {"ok":false,"reason":"存檔版本比目前遊戲新。"}
	if version == 2 and envelope.get("world_state",{}) is Dictionary:
		return {"ok":true,"data":envelope.duplicate(true)}
	if version != 1 or not (envelope.get("world",{}) is Dictionary):
		return {"ok":false,"reason":"存檔結構不完整。"}
	var state: Dictionary = envelope["world"].duplicate(true)
	state.erase("save_version")
	var defaults: Dictionary = WorldStateData.expansion_defaults()
	for key in defaults:
		if not state.has(key): state[key] = defaults[key]
	return {"ok":true,"data":{"save_version":2,"time":envelope.get("time",{}).duplicate(true),"world_state":state}}
