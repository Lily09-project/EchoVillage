class_name StoryArcService
extends RefCounted

const MAX_ARCS := 32
const MAX_STAGES_PER_ARC := 32
const MAX_CHOICES_PER_STAGE := 16
const MAX_CONSEQUENCES_PER_CHOICE := 16
const MAX_TEXT_LENGTH := 240
const VALID_TRIGGER_KINDS := ["community_flag", "quest_active", "active_event", "world_flag"]
const VALID_CONSEQUENCE_KINDS := ["relationship", "memory", "community", "world_flag", "coin", "inventory"]

var owner = null
var definitions: Dictionary = {}
var state: Dictionary = {"schema_version":1,"arcs":{}}

func configure(manager, raw: Variant) -> bool:
	owner = manager
	if not (raw is Dictionary): return false
	var entries = raw.get("arcs",[])
	if not (entries is Array) or entries.size() > MAX_ARCS: return false
	var indexed: Dictionary = {}
	for entry in entries:
		if not _valid_definition(entry): return false
		var arc_id := str(entry.get("id",""))
		if indexed.has(arc_id): return false
		indexed[arc_id] = entry.duplicate(true)
	definitions = indexed
	return not definitions.is_empty()

func reset() -> void:
	state = {"schema_version":1,"arcs":{}}

func default_state() -> Dictionary:
	return {"schema_version":1,"arcs":{}}

func validate_state(raw: Variant) -> bool:
	if not (raw is Dictionary): return false
	var arcs = raw.get("arcs",{})
	if not (arcs is Dictionary) or arcs.size() > MAX_ARCS: return false
	for arc_id in arcs:
		if not definitions.has(str(arc_id)): return false
		var record = arcs[arc_id]
		if not (record is Dictionary): return false
		if str(record.get("status","")) not in ["active","completed"]: return false
		var stage_id := str(record.get("stage_id",""))
		if not stage_id.is_empty() and _stage_definition(str(arc_id),stage_id).is_empty(): return false
		var choices = record.get("choices_made",[])
		if not (choices is Array) or choices.size() > MAX_CHOICES_PER_STAGE: return false
		for choice_id in choices:
			if not (choice_id is String) or str(choice_id).length() > 64: return false
	return true

func load_state(raw: Variant) -> bool:
	if not validate_state(raw): return false
	state = {"schema_version":1,"arcs":raw.get("arcs",{}).duplicate(true)}
	return true

func serialize() -> Dictionary:
	return state.duplicate(true)

func refresh() -> Array:
	var activated: Array = []
	if owner == null: return activated
	var arcs: Dictionary = state.get("arcs",{})
	for arc_id in definitions:
		var id := str(arc_id)
		if arcs.has(id): continue
		var definition: Dictionary = definitions[id]
		if not _trigger_met(definition.get("trigger",{})): continue
		var first_stage: Dictionary = definition.get("stages",[])[0]
		arcs[id] = {"status":"active","stage_id":str(first_stage.get("id","")),"choices_made":[],"started_at":_timestamp()}
		activated.append(id)
		owner.add_log("故事線開始：「%s」" % str(definition.get("title",id)))
		EventBus.story_arc_updated.emit(id,str(first_stage.get("id","")),{"kind":"started"})
	return activated

func snapshot() -> Dictionary:
	var result: Dictionary = {"schema_version":1,"arcs":{}}
	var records: Dictionary = state.get("arcs",{})
	for arc_id in definitions:
		var id := str(arc_id)
		var definition: Dictionary = definitions[id]
		var record: Dictionary = records.get(id,{"status":"locked","stage_id":"","choices_made":[]}).duplicate(true)
		record["id"] = id
		record["title"] = str(definition.get("title",id))
		record["summary"] = str(definition.get("summary",""))
		if str(record.get("status","")) == "active":
			var stage: Dictionary = _stage_definition(id,str(record.get("stage_id","")))
			record["stage"] = _stage_view(stage)
		else:
			record["stage"] = {}
		result["arcs"][id] = record
	return result

func available_choices(arc_id: String) -> Array:
	var record: Dictionary = state.get("arcs",{}).get(arc_id,{})
	if str(record.get("status","")) != "active": return []
	var stage: Dictionary = _stage_definition(arc_id,str(record.get("stage_id","")))
	if stage.is_empty(): return []
	var used: Array = record.get("choices_made",[])
	var result: Array = []
	for choice in stage.get("choices",[]):
		if str(choice.get("id","")) not in used:
			result.append({"id":str(choice.get("id","")),"label":str(choice.get("label","")),"description":str(choice.get("description",""))})
	return result

func apply_choice(arc_id: String, choice_id: String) -> Dictionary:
	var record: Dictionary = state.get("arcs",{}).get(arc_id,{})
	if str(record.get("status","")) != "active": return {"ok":false,"reason":"這條故事線目前沒有可選擇的進度。"}
	var stage: Dictionary = _stage_definition(arc_id,str(record.get("stage_id","")))
	if stage.is_empty(): return {"ok":false,"reason":"故事階段資料無效。"}
	var choice: Dictionary = {}
	for candidate in stage.get("choices",[]):
		if str(candidate.get("id","")) == choice_id: choice = candidate.duplicate(true); break
	if choice.is_empty(): return {"ok":false,"reason":"找不到這個故事選擇。"}
	if choice_id in record.get("choices_made",[]): return {"ok":false,"reason":"這個選擇已經處理過。"}
	if not _can_apply_consequences(choice.get("consequences",[])): return {"ok":false,"reason":"這個選擇的後果資料無法安全套用。"}
	_apply_consequences(arc_id,choice.get("consequences",[]))
	record["choices_made"].append(choice_id)
	var next_stage := str(choice.get("next_stage",""))
	var completed := next_stage.is_empty()
	if completed:
		record["status"] = "completed"
		record["completed_at"] = _timestamp()
		record["stage_id"] = ""
	else:
		record["stage_id"] = next_stage
	state["arcs"][arc_id] = record
	var definition: Dictionary = definitions.get(arc_id,{})
	var message := "故事線完成：「%s」" % str(definition.get("title",arc_id)) if completed else "故事線推進：「%s」" % str(definition.get("title",arc_id))
	owner.add_log(message)
	EventBus.story_arc_updated.emit(arc_id, next_stage, {"kind":"completed" if completed else "advanced","choice_id":choice_id})
	return {"ok":true,"arc_id":arc_id,"arc_title":str(definition.get("title",arc_id)),"choice_id":choice_id,"choice_label":str(choice.get("label",choice_id)),"actors":_choice_actors(choice),"completed":completed,"snapshot":snapshot().get("arcs",{}).get(arc_id,{})}

func _choice_actors(choice: Dictionary) -> Array:
	var actors: Array[String] = ["player"]
	for consequence in choice.get("consequences",[]):
		var npc_id := str(consequence.get("npc_id",""))
		if not npc_id.is_empty() and npc_id not in actors: actors.append(npc_id)
	return actors

func _timestamp() -> String:
	return GameTime.formatted_time()

func _trigger_met(trigger: Variant) -> bool:
	if not (trigger is Dictionary) or owner == null: return false
	match str(trigger.get("kind","")):
		"community_flag": return bool(owner.community.get(str(trigger.get("flag","")),false))
		"quest_active": return owner.active_quests.has(str(trigger.get("quest_id","")))
		"active_event": return str(owner.active_event.get("id","")) == str(trigger.get("event_id",""))
		"world_flag": return bool(owner.world_flags.get(str(trigger.get("flag","")),false))
	return false

func _stage_definition(arc_id: String, stage_id: String) -> Dictionary:
	var definition: Dictionary = definitions.get(arc_id,{})
	for stage in definition.get("stages",[]):
		if str(stage.get("id","")) == stage_id: return stage
	return {}

func _stage_view(stage: Dictionary) -> Dictionary:
	if stage.is_empty(): return {}
	return {"id":str(stage.get("id","")),"title":str(stage.get("title","")),"description":str(stage.get("description","")),"choices":available_choices_for_stage(stage)}

func available_choices_for_stage(stage: Dictionary) -> Array:
	var result: Array = []
	for choice in stage.get("choices",[]):
		result.append({"id":str(choice.get("id","")),"label":str(choice.get("label","")),"description":str(choice.get("description",""))})
	return result

func _can_apply_consequences(consequences: Variant) -> bool:
	if not (consequences is Array) or consequences.size() > MAX_CONSEQUENCES_PER_CHOICE: return false
	for consequence in consequences:
		if not (consequence is Dictionary): return false
		var kind := str(consequence.get("kind",""))
		if kind not in VALID_CONSEQUENCE_KINDS: return false
		match kind:
			"relationship":
				if owner == null or not owner.npcs.has(str(consequence.get("npc_id",""))): return false
				if not (consequence.get("changes",{}) is Dictionary): return false
			"memory":
				if owner == null or not owner.npcs.has(str(consequence.get("npc_id",""))): return false
				for key in ["memory_type","description"]:
					if not (consequence.get(key,"") is String) or str(consequence.get(key,"")).length() > MAX_TEXT_LENGTH: return false
			"community":
				if str(consequence.get("flag","")).is_empty() or str(consequence.get("title","")).length() > MAX_TEXT_LENGTH: return false
			"world_flag":
				if str(consequence.get("flag","")).is_empty(): return false
			"coin":
				if not _finite_number(consequence.get("amount",0)): return false
			"inventory":
				if owner == null or not owner.item_defs.has(str(consequence.get("item_id",""))): return false
				if not (consequence.get("amount",0) is int) or int(consequence.get("amount",0)) == 0: return false
	return true

func _apply_consequences(arc_id: String, consequences: Array) -> void:
	for consequence in consequences:
		var kind := str(consequence.get("kind",""))
		match kind:
			"relationship":
				owner.change_relationship(owner.npcs[str(consequence["npc_id"])],str(consequence.get("target_id","player")),consequence.get("changes",{}))
			"memory":
				owner.create_memory(str(consequence["npc_id"]),str(consequence["memory_type"]),str(consequence["description"]),float(consequence.get("emotional_value",0.0)),int(consequence.get("importance",20)),"player",str(consequence["npc_id"]),{"story_arc":arc_id})
			"community":
				owner.record_community(str(consequence["flag"]),int(consequence.get("renown",0)),str(consequence.get("title","故事回音")),str(consequence.get("description","")))
			"world_flag": owner.world_flags[str(consequence["flag"])] = consequence.get("value",true)
			"coin": owner.player["coin"] = maxi(0,int(owner.player.get("coin",0)) + int(consequence.get("amount",0)))
			"inventory":
				var amount := int(consequence.get("amount",0))
				if amount > 0: owner.add_item(owner.player["inventory"],str(consequence["item_id"]),amount)
				else: owner.remove_item(owner.player["inventory"],str(consequence["item_id"]),-amount)

func _valid_definition(value: Variant) -> bool:
	if not (value is Dictionary): return false
	var definition: Dictionary = value
	for key in ["id","title","summary"]:
		if not (definition.get(key,"") is String) or str(definition.get(key,"")).is_empty() or str(definition.get(key,"")).length() > MAX_TEXT_LENGTH: return false
	var trigger = definition.get("trigger",{})
	if not (trigger is Dictionary) or str(trigger.get("kind","")) not in VALID_TRIGGER_KINDS: return false
	var stages = definition.get("stages",[])
	if not (stages is Array) or stages.is_empty() or stages.size() > MAX_STAGES_PER_ARC: return false
	var stage_ids: Dictionary = {}
	for stage in stages:
		if not (stage is Dictionary): return false
		var stage_id := str(stage.get("id",""))
		if stage_id.is_empty() or stage_ids.has(stage_id): return false
		stage_ids[stage_id] = true
		for key in ["title","description"]:
			if not (stage.get(key,"") is String) or str(stage.get(key,"")).length() > MAX_TEXT_LENGTH: return false
		var choices = stage.get("choices",[])
		if not (choices is Array) or choices.is_empty() or choices.size() > MAX_CHOICES_PER_STAGE: return false
		var choice_ids: Dictionary = {}
		for choice in choices:
			if not (choice is Dictionary): return false
			var choice_id := str(choice.get("id",""))
			if choice_id.is_empty() or choice_ids.has(choice_id): return false
			choice_ids[choice_id] = true
			for key in ["label","description"]:
				if not (choice.get(key,"") is String) or str(choice.get(key,"")).length() > MAX_TEXT_LENGTH: return false
			if not _valid_consequences(choice.get("consequences",[])): return false
			var next_stage := str(choice.get("next_stage",""))
			if not next_stage.is_empty() and next_stage not in stage_ids and next_stage not in _stage_ids(stages): return false
	return true

func _stage_ids(stages: Array) -> Array:
	var ids: Array = []
	for stage in stages: ids.append(str(stage.get("id","")))
	return ids

func _valid_consequences(value: Variant) -> bool:
	if not (value is Array) or value.size() > MAX_CONSEQUENCES_PER_CHOICE: return false
	for consequence in value:
		if not (consequence is Dictionary) or str(consequence.get("kind","")) not in VALID_CONSEQUENCE_KINDS: return false
	return true

func _finite_number(value: Variant) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and absf(float(value)) <= 1000000.0
