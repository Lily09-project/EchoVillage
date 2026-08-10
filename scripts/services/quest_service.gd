class_name QuestService
extends RefCounted

var definitions: Dictionary

func _init(quest_definitions: Dictionary) -> void:
	definitions = quest_definitions

func accept(active: Dictionary, completed: Array, quest_id: String) -> Dictionary:
	if not definitions.has(quest_id): return {"ok":false,"reason":"找不到這項任務。"}
	if active.has(quest_id) or quest_id in completed: return {"ok":false,"reason":"任務已接受或完成。"}
	var definition: Dictionary = definitions[quest_id]
	for prerequisite in definition.get("prerequisites",[]):
		if str(prerequisite) not in completed: return {"ok":false,"reason":"尚未達成前置任務。"}
	active[quest_id] = {"quest_id":quest_id,"objective_index":0,"progress":0,"status":"active"}
	return {"ok":true,"reason":"","quest_id":quest_id}

func current_objective(active: Dictionary, quest_id: String) -> Dictionary:
	if not active.has(quest_id) or not definitions.has(quest_id): return {}
	var index := int(active[quest_id].get("objective_index",0))
	var objectives: Array = definitions[quest_id].get("objectives",[])
	return objectives[index] if index >= 0 and index < objectives.size() else {}

func notify(active: Dictionary, completed: Array, event_kind: String, target_id: String, amount: int = 1) -> Dictionary:
	var changed: Array[String] = []
	var completed_now: Array[String] = []
	for quest_id_value in active.keys().duplicate():
		var quest_id := str(quest_id_value)
		var objective := current_objective(active,quest_id)
		if objective.is_empty() or str(objective.get("kind","")) != event_kind or str(objective.get("target_id","")) != target_id: continue
		var runtime: Dictionary = active[quest_id]
		runtime["progress"] = mini(int(objective.get("amount",1)),int(runtime.get("progress",0)) + amount)
		if int(runtime["progress"]) >= int(objective.get("amount",1)):
			runtime["objective_index"] = int(runtime["objective_index"]) + 1
			runtime["progress"] = 0
			if int(runtime["objective_index"]) >= int(definitions[quest_id].get("objectives",[]).size()):
				active.erase(quest_id)
				if quest_id not in completed: completed.append(quest_id)
				completed_now.append(quest_id)
		changed.append(quest_id)
	return {"changed":changed,"completed":completed_now}

func snapshot(active: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for quest_id_value in active:
		var quest_id := str(quest_id_value)
		var definition: Dictionary = definitions.get(quest_id,{})
		var runtime: Dictionary = active[quest_id]
		result.append({"id":quest_id,"title":definition.get("title",quest_id),"description":definition.get("description",""),"objective":current_objective(active,quest_id).duplicate(true),"objective_index":runtime.get("objective_index",0),"progress":runtime.get("progress",0),"rewards":definition.get("rewards",{}).duplicate(true)})
	return result
