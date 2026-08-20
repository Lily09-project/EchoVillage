class_name AIService
extends RefCounted

const MAX_CONTEXT_TEXT_CHARS := 500
const MAX_CONTEXT_MEMORIES := 64
const MAX_DIALOGUE_CHARS := 500
const MAX_INTENT_CHARS := 64

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
	var important: Array = []
	for memory in memories:
		if memory is Dictionary: important.append(memory.duplicate(true))
	if important.is_empty(): return "目前沒有重要記憶。"
	important.sort_custom(func(a,b): return int(a.get("importance",0)) > int(b.get("importance",0)))
	var descriptions: Array[String] = []
	for memory in important.slice(0,mini(3,important.size())):
		var description := str(memory.get("description","" )).strip_edges()
		if description.length() > MAX_CONTEXT_TEXT_CHARS: description = description.left(MAX_CONTEXT_TEXT_CHARS)
		if not description.is_empty(): descriptions.append(description)
	if descriptions.is_empty(): return "目前沒有重要記憶。"
	return "；".join(descriptions)

func generate_long_term_goal(context: Dictionary) -> String:
	var profile = context.get("npc_profile",{})
	var occupation := str(profile.get("occupation","居民")) if profile is Dictionary else "居民"
	if occupation.is_empty(): occupation = "居民"
	if occupation.length() > 64: occupation = occupation.left(64)
	return "以%s的身分，讓村落生活變得更安穩。" % occupation

func sanitize_context(context: Dictionary) -> Dictionary:
	var allowed := ["npc_profile","mood","relevant_memories","relationship","world_event","situation"]
	var result: Dictionary = {}
	for key in allowed:
		if not context.has(key): continue
		var value = context[key]
		if key == "npc_profile":
			result[key] = value.duplicate(true) if value is Dictionary else {}
		elif key == "relevant_memories":
			var safe_memories: Array = []
			if value is Array:
				for memory in value:
					if memory is Dictionary:
						safe_memories.append(memory.duplicate(true))
						if safe_memories.size() >= MAX_CONTEXT_MEMORIES: break
			result[key] = safe_memories
		elif key == "mood" or key == "situation":
			result[key] = str(value).left(MAX_CONTEXT_TEXT_CHARS)
		else:
			result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result

func valid_dialogue_response(response: Dictionary) -> bool:
	var dialogue := str(response.get("dialogue","")).strip_edges()
	var emotion := str(response.get("emotion",""))
	var intent := str(response.get("intent","" )).strip_edges()
	return response.has_all(["dialogue","emotion","intent"]) and not dialogue.is_empty() and dialogue.length() <= MAX_DIALOGUE_CHARS and emotion in ["happy","neutral","sad","angry","afraid","tired"] and not intent.is_empty() and intent.length() <= MAX_INTENT_CHARS

func template_fallback(context: Dictionary) -> Dictionary:
	var mood := str(context.get("mood","Neutral")).to_lower()
	var lines := {"happy":"很高興見到你。今天的村子很有精神。","sad":"今天有些安靜，陪我說說話吧。","angry":"我現在需要一點空間。","afraid":"外頭似乎不太安全，請小心。","tired":"忙了一整天，我想先休息。","neutral":"早安，村裡的一切都還好嗎？"}
	return {"dialogue":str(lines.get(mood,lines["neutral"])),"emotion":mood if mood in lines else "neutral","intent":"small_talk"}
