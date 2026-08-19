class_name SaveMigration
extends RefCounted

const WorldStateData = preload("res://scripts/core/world_state.gd")
const MAX_NPCS := 64
const MAX_TIMELINE_EVENTS := 512
const MAX_EVENT_LOG_ENTRIES := 512
const MAX_MEMORIES_PER_NPC := 128
const MAX_SAVE_DAY := 1000000

static func migrate(envelope: Dictionary) -> Dictionary:
	var raw_version = envelope.get("save_version",1)
	var version: int
	if raw_version is int:
		version = int(raw_version)
	elif raw_version is float and float(raw_version) == floor(float(raw_version)):
		version = int(raw_version)
	else:
		return {"ok":false,"reason":"存檔版本格式無效。"}
	if version > 2: return {"ok":false,"reason":"存檔版本比目前遊戲新。"}
	if envelope.has("time") and not _valid_time(envelope.get("time")):
		return {"ok":false,"reason":"存檔時間資料格式無效。"}
	if version == 2:
		if not _valid_world_state(envelope.get("world_state")): return {"ok":false,"reason":"存檔世界資料格式無效。"}
		return {"ok":true,"data":envelope.duplicate(true)}
	if version != 1 or not _valid_world_state(envelope.get("world")):
		return {"ok":false,"reason":"存檔結構不完整。"}
	var state: Dictionary = envelope["world"].duplicate(true)
	state.erase("save_version")
	var defaults: Dictionary = WorldStateData.expansion_defaults()
	for key in defaults:
		if not state.has(key): state[key] = defaults[key]
	return {"ok":true,"data":{"save_version":2,"time":envelope.get("time",{}).duplicate(true),"world_state":state}}

static func _valid_world_state(value: Variant) -> bool:
	if not (value is Dictionary): return false
	var state: Dictionary = value
	var player = state.get("player")
	var npcs = state.get("npcs")
	if not (player is Dictionary) or not (npcs is Dictionary): return false
	if not (player.get("inventory") is Dictionary): return false
	if npcs.size() > MAX_NPCS: return false
	for npc_id in npcs:
		var npc = npcs[npc_id]
		if not (npc is Dictionary): return false
		if npc.has("memories"):
			if not (npc.get("memories") is Array) or npc.get("memories").size() > MAX_MEMORIES_PER_NPC: return false
	if state.has("event_log"):
		if not (state.get("event_log") is Array) or state.get("event_log").size() > MAX_EVENT_LOG_ENTRIES: return false
	if state.has("timeline_events"):
		if not (state.get("timeline_events") is Array) or state.get("timeline_events").size() > MAX_TIMELINE_EVENTS: return false
	if state.has("economy") and not (state.get("economy") is Dictionary): return false
	if state.has("community") and not (state.get("community") is Dictionary): return false
	if state.has("active_event") and not (state.get("active_event") is Dictionary): return false
	if state.has("discovered_locations") and not (state.get("discovered_locations") is Array): return false
	if state.has("completed_quests") and not (state.get("completed_quests") is Array): return false
	if state.has("active_quests") and not (state.get("active_quests") is Dictionary): return false
	if state.has("world_flags") and not (state.get("world_flags") is Dictionary): return false
	if state.has("progression") and not (state.get("progression") is Dictionary): return false
	return true

static func _valid_time(value: Variant) -> bool:
	if not (value is Dictionary): return false
	var time: Dictionary = value
	if time.has("minute") and not _valid_integral_range(time.get("minute"),0,1439): return false
	if time.has("day") and not _valid_integral_range(time.get("day"),1,MAX_SAVE_DAY): return false
	if time.has("day_of_week") and not _valid_integral_range(time.get("day_of_week"),1,7): return false
	if time.has("time_scale") and not _valid_number_range(time.get("time_scale"),0.01,10.0): return false
	return true

static func _valid_integral_range(value: Variant, minimum: float, maximum: float) -> bool:
	if not (value is int or value is float): return false
	var number := float(value)
	return number == floor(number) and number >= minimum and number <= maximum

static func _valid_number_range(value: Variant, minimum: float, maximum: float) -> bool:
	if not (value is int or value is float): return false
	var number := float(value)
	return number >= minimum and number <= maximum
