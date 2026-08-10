extends Node

const REQUIRED_FIELDS := ["id","start_time","duration","effects","notifications"]

func valid_definition(definition: Dictionary) -> bool:
	return definition.has_all(REQUIRED_FIELDS) and int(definition.get("duration",0)) > 0 and definition.get("effects",{}) is Dictionary and definition.get("notifications",[]) is Array

func start_event(definition: Dictionary, current_minute: int) -> Dictionary:
	if not valid_definition(definition): return {}
	var event: Dictionary = definition.duplicate(true)
	event["started_at"] = current_minute
	event["remaining_minutes"] = int(event["duration"])
	event["ends_at"] = current_minute + int(event["duration"])
	return event

func advance_event(active_event: Dictionary, elapsed_minutes: int = 1) -> Dictionary:
	if active_event.is_empty(): return {"ended":false,"event":{}}
	var event: Dictionary = active_event.duplicate(true)
	event["remaining_minutes"] = int(event.get("remaining_minutes",event.get("duration",0))) - maxi(0,elapsed_minutes)
	if int(event["remaining_minutes"]) <= 0: return {"ended":true,"event":{}}
	return {"ended":false,"event":event}

func effects_for(active_event: Dictionary) -> Dictionary:
	return active_event.get("effects",{}).duplicate(true)
