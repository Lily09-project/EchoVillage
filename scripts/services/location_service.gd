class_name LocationService
extends RefCounted

var definitions: Dictionary

func _init(location_definitions: Dictionary) -> void:
	definitions = location_definitions

func travel(current_id: String, discovered: Array, flags: Dictionary, target_id: String) -> Dictionary:
	if not definitions.has(target_id): return {"ok":false,"reason":"找不到這個地點。"}
	if current_id == target_id: return {"ok":false,"reason":"你已經在這裡。"}
	if not definitions.has(current_id): return {"ok":false,"reason":"目前地點資料無效。"}
	var current: Dictionary = definitions[current_id]
	if target_id not in current.get("neighbors",[]): return {"ok":false,"reason":"無法從目前地點直接前往。"}
	var target: Dictionary = definitions[target_id]
	for requirement in target.get("unlock_requirements",[]):
		if not bool(flags.get(str(requirement),false)): return {"ok":false,"reason":"此地點尚未解鎖。"}
	var next_discovered := discovered.duplicate(true)
	if target_id not in next_discovered: next_discovered.append(target_id)
	return {"ok":true,"reason":"","location_id":target_id,"discovered_locations":next_discovered}
