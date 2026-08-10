class_name AIService
extends RefCounted

var provider

func _init(dialogue_provider = null) -> void:
	provider = dialogue_provider

func generate_dialogue(context: Dictionary) -> Dictionary:
	var safe_context: Dictionary = sanitize_context(context)
	if provider != null and provider.has_method("request_dialogue"):
		var candidate = provider.request_dialogue(safe_context)
		if candidate is Dictionary and valid_dialogue_response(candidate):
			return {"dialogue":str(candidate["dialogue"]),"emotion":str(candidate["emotion"]),"intent":str(candidate["intent"])}
	return template_fallback(safe_context)

func summarize_memories(memories: Array) -> String:
	if memories.is_empty(): return "目前沒有重要記憶。"
	var important := memories.duplicate(true)
	important.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.get("importance",0)) > int(b.get("importance",0)))
	var descriptions: Array[String] = []
	for memory in important.slice(0,mini(3,important.size())): descriptions.append(str(memory.get("description","")))
	return "；".join(descriptions)

func generate_long_term_goal(context: Dictionary) -> String:
	var occupation := str(context.get("npc_profile",{}).get("occupation","居民"))
	return "以%s的身分，讓村落生活變得更安穩。" % occupation

func sanitize_context(context: Dictionary) -> Dictionary:
	var allowed := ["npc_profile","mood","relevant_memories","relationship","world_event","situation"]
	var result := {}
	for key in allowed:
		if context.has(key): result[key] = context[key].duplicate(true) if context[key] is Dictionary or context[key] is Array else context[key]
	return result

func valid_dialogue_response(response: Dictionary) -> bool:
	return response.has_all(["dialogue","emotion","intent"]) and str(response["dialogue"]).strip_edges() != "" and str(response["emotion"]) in ["happy","neutral","sad","angry","afraid","tired"]

func template_fallback(context: Dictionary) -> Dictionary:
	var mood := str(context.get("mood","Neutral")).to_lower()
	var lines := {"happy":"很高興見到你。今天的村子很有精神。","sad":"今天有些安靜，陪我說說話吧。","angry":"我現在需要一點空間。","afraid":"外頭似乎不太安全，請小心。","tired":"忙了一整天，我想先休息。","neutral":"早安，村裡的一切都還好嗎？"}
	return {"dialogue":str(lines.get(mood,lines["neutral"])),"emotion":mood if mood in lines else "neutral","intent":"small_talk"}
