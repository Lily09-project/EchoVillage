class_name CausalityHistoryService
extends RefCounted

const VALID_EFFECT_KINDS := ["relationship","memory","story","community","quest","world","economy","location","simulation"]
const MAX_ACTORS := 4
const MAX_ACTOR_ID_LENGTH := 64
const MAX_EFFECT_KEYS := 16
const MAX_EFFECT_DEPTH := 4
const MAX_EFFECT_COLLECTION := 16
const MAX_TEXT_LENGTH := 512
const RELATIONSHIP_LABELS := {"trust":"信任","affinity":"好感","fear":"恐懼","respect":"尊敬"}
const RELATIONSHIP_ORDER := ["trust","affinity","fear","respect"]

func normalize_details(raw: Variant) -> Dictionary:
	if not (raw is Dictionary): return {}
	var kind := str(raw.get("effect_kind",""))
	if kind not in VALID_EFFECT_KINDS: return {}
	var actors := _normalize_actors(raw.get("actors",[]))
	var effect = raw.get("effect",{})
	if not _effect_is_safe(effect): return {}
	return {"effect_kind":kind,"actors":actors,"effect":effect.duplicate(true)}

func validate_event(value: Variant) -> bool:
	if not (value is Dictionary): return false
	var event: Dictionary = value
	if not (event.get("message","") is String) or str(event.get("message","")).length() > MAX_TEXT_LENGTH: return false
	if event.has("id") and (not (event.get("id") is String) or str(event.get("id","")).length() > 96): return false
	if event.has("category") and (not (event.get("category") is String) or str(event.get("category","")).length() > 32): return false
	if event.has("day") and not _is_non_negative_integer(event.get("day")): return false
	if event.has("minute") and not _is_non_negative_integer(event.get("minute")): return false
	var has_any_details := event.has("effect_kind") or event.has("actors") or event.has("effect")
	if not has_any_details: return true
	if not event.has_all(["effect_kind","actors","effect"]): return false
	var kind := str(event.get("effect_kind",""))
	if kind not in VALID_EFFECT_KINDS: return false
	var actors = event.get("actors",[])
	if not (actors is Array) or actors.size() > MAX_ACTORS: return false
	for actor in actors:
		if not (actor is String) or str(actor).is_empty() or str(actor).length() > MAX_ACTOR_ID_LENGTH: return false
	return _effect_is_safe(event.get("effect",{}))

func query(events: Array, actor_id: String = "", effect_kind: String = "all", limit: int = 20) -> Array:
	var safe_actor := actor_id.strip_edges().left(MAX_ACTOR_ID_LENGTH)
	var safe_kind := effect_kind if effect_kind in VALID_EFFECT_KINDS else "all"
	var safe_limit := clampi(limit,1,50)
	var result: Array = []
	for index in range(events.size() - 1,-1,-1):
		var value = events[index]
		if not (value is Dictionary): continue
		var event: Dictionary = value
		var kind := str(event.get("effect_kind",""))
		if kind not in VALID_EFFECT_KINDS: continue
		if safe_kind != "all" and kind != safe_kind: continue
		if not safe_actor.is_empty() and safe_actor not in event.get("actors",[]): continue
		result.append(event.duplicate(true))
		if result.size() >= safe_limit: break
	return result

func format_event(event: Dictionary, actor_names: Dictionary = {}) -> String:
	var kind := str(event.get("effect_kind",""))
	var effect: Dictionary = event.get("effect",{})
	var day := int(event.get("day",1))
	var time_text := str(event.get("time",""))
	var prefix := "第 %d 天" % day
	if not time_text.is_empty(): prefix += " · " + _short_time(time_text)
	match kind:
		"relationship":
			var npc_id := str(effect.get("npc_id",""))
			var target_id := str(effect.get("target_id","player"))
			return "%s  %s → %s｜%s" % [prefix,_actor_name(npc_id,actor_names),_actor_name(target_id,actor_names),relationship_delta_text(effect.get("changes",{}))]
		"memory":
			var npc_id := str(effect.get("npc_id",""))
			return "%s  %s 留下「%s」記憶｜重要度 %d" % [prefix,_actor_name(npc_id,actor_names),memory_kind_label(str(effect.get("memory_type","事件"))),int(effect.get("importance",0))]
		"story":
			return "%s  故事選擇｜%s → %s" % [prefix,str(effect.get("arc_title",effect.get("arc_id","故事"))),str(effect.get("choice_label",effect.get("choice_id","選擇")))]
	return "%s  %s" % [prefix,str(event.get("message","一段尚未命名的回音"))]

func relationship_delta_text(changes: Dictionary) -> String:
	var parts: Array[String] = []
	for key in RELATIONSHIP_ORDER:
		if not changes.has(key): continue
		var value := float(changes.get(key,0.0))
		if absf(value) < 0.001: continue
		parts.append("%s %s" % [str(RELATIONSHIP_LABELS[key]),_signed_number(value)])
	return "、".join(parts) if not parts.is_empty() else "關係未改變"

func memory_kind_label(kind: String) -> String:
	var labels := {
		"small_talk":"日常交談","gift_received":"收到贈禮","player_gave_item":"收到贈禮","caught_stealing":"目睹偷竊","player_stole_item":"目睹偷竊",
		"trade_event":"完成交易","story_apology":"真誠道歉","story_denial":"否認與疑慮",
		"story_forest_kindness":"森林中的照顧","story_forest_delay":"延後的承諾",
		"story_festival_help":"祭典協力","npc_argued":"居民爭執","npc_helped_npc":"受到協助",
		"helped_npc":"幫助居民","npc_injury":"居民受傷","quest_completed":"完成任務"
	}
	return str(labels.get(kind,kind.replace("_"," ")))

func _normalize_actors(value: Variant) -> Array:
	var result: Array[String] = []
	if not (value is Array): return result
	for actor in value:
		if not (actor is String): continue
		var actor_id := str(actor).strip_edges().left(MAX_ACTOR_ID_LENGTH)
		if actor_id.is_empty() or actor_id in result: continue
		result.append(actor_id)
		if result.size() >= MAX_ACTORS: break
	return result

func _effect_is_safe(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_EFFECT_DEPTH: return false
	if value == null or value is bool or value is int: return true
	if value is float: return is_finite(float(value)) and absf(float(value)) <= 1000000.0
	if value is String: return str(value).length() <= MAX_TEXT_LENGTH
	if value is Array:
		if value.size() > MAX_EFFECT_COLLECTION: return false
		for child in value:
			if not _effect_is_safe(child,depth + 1): return false
		return true
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.size() > MAX_EFFECT_KEYS: return false
		for key in dictionary:
			if not (key is String) or str(key).length() > 64: return false
			if not _effect_is_safe(dictionary[key],depth + 1): return false
		return true
	return false

func _actor_name(actor_id: String, names: Dictionary) -> String:
	if actor_id == "player": return "玩家"
	return str(names.get(actor_id,actor_id if not actor_id.is_empty() else "未知居民"))

func _signed_number(value: float) -> String:
	var rounded := roundf(value * 10.0) / 10.0
	var number := str(int(rounded)) if is_equal_approx(rounded,roundf(rounded)) else "%.1f" % rounded
	return ("+" if rounded > 0.0 else "") + number

func _short_time(value: String) -> String:
	var pieces := value.split(" ")
	return str(pieces[-1]) if not pieces.is_empty() else value

func _is_non_negative_integer(value: Variant) -> bool:
	if not (value is int or value is float): return false
	var number := float(value)
	return is_finite(number) and number >= 0.0 and number == floor(number)
