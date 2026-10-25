class_name DialogueGrammar
extends RefCounted

## Grammar-based dialogue: opener (mood) + body (memory, rumour, need or
## topic) + closer (tone). Every slot is filled from the villager's own state,
## so a line only mentions people and events the villager actually remembers
## or has heard about. A seeded generator picks among valid variants, so the
## same state and seed always produce the same line.

const MEMORY_THRESHOLD := 10.0

var rules: Dictionary = {}
var max_length := 90

func configure(data: Dictionary) -> bool:
	for key in ["openers","memory_positive","memory_negative","rumor","rumor_doubt","need_hunger","need_energy","topic","closers"]:
		if not data.has(key): return false
	rules = data.duplicate(true)
	max_length = clampi(int(data.get("max_length",90)),40,160)
	return true

## context: {"rumors": [{"id","text","teller_id","credibility"}], "names": {id: name}}
## Returns {"text", "parts": [rule keys], "references": {"memories","rumors","actors"}}.
func generate(npc: Dictionary, context: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed)
	var names: Dictionary = context.get("names",{})
	var parts: Array = []
	var references := {"memories":[],"rumors":[],"actors":[]}
	var opener := _pick(rng,rules["openers"].get(str(npc.get("mood","Neutral")),rules["openers"].get("Neutral",[""])))
	parts.append("opener")
	var body := ""
	var memory := _salient_memory(npc)
	var rumors: Array = context.get("rumors",[])
	var hunger := float(npc.get("needs",{}).get("hunger",0.0))
	var energy := float(npc.get("needs",{}).get("energy",100.0))
	if not memory.is_empty():
		var positive := float(memory.get("emotional_value",0.0)) > 0.0
		body = _pick(rng,rules["memory_positive" if positive else "memory_negative"]).replace("{memory_text}",_memory_text(memory,names))
		parts.append("memory_positive" if positive else "memory_negative")
		references["memories"].append(str(memory.get("id","")))
		for actor in [str(memory.get("subject_id","")),str(memory.get("object_id",""))]:
			if not actor.is_empty() and actor not in references["actors"]: references["actors"].append(actor)
	elif not rumors.is_empty():
		var rumor: Dictionary = rumors[0]
		var doubtful := float(rumor.get("credibility",1.0)) < 0.6
		var template := _pick(rng,rules["rumor_doubt" if doubtful else "rumor"])
		body = template.replace("{rumor_text}",str(rumor.get("text",""))).replace("{teller}",str(names.get(str(rumor.get("teller_id","")),"有人")))
		parts.append("rumor_doubt" if doubtful else "rumor")
		references["rumors"].append(str(rumor.get("id","")))
		if not str(rumor.get("teller_id","")).is_empty(): references["actors"].append(str(rumor.get("teller_id","")))
	elif hunger >= 70.0:
		body = _pick(rng,rules["need_hunger"])
		parts.append("need_hunger")
	elif energy <= 25.0:
		body = _pick(rng,rules["need_energy"])
		parts.append("need_energy")
	else:
		var topics: Array = npc.get("dialogue_profile",{}).get("topics",[])
		if not topics.is_empty():
			body = _pick(rng,rules["topic"]).replace("{topic}",str(topics[rng.randi_range(0,topics.size() - 1)]))
			parts.append("topic")
	var text := opener + body
	var closer := _pick(rng,rules["closers"].get(str(npc.get("dialogue_profile",{}).get("tone","")),[]))
	if not closer.is_empty() and (text + closer).length() <= max_length:
		text += closer
		parts.append("closer")
	if text.length() > max_length: text = text.left(max_length - 1) + "…"
	return {"text":text,"parts":parts,"references":references}

func _salient_memory(npc: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	for value in npc.get("memories",[]):
		var memory: Dictionary = value
		if absf(float(memory.get("emotional_value",0.0))) < MEMORY_THRESHOLD: continue
		if str(memory.get("event_type","")).begins_with("heard_"): continue
		if best.is_empty() or int(memory.get("importance",0)) >= int(best.get("importance",0)): best = memory
	return best

func _memory_text(memory: Dictionary, names: Dictionary) -> String:
	var subject := str(memory.get("subject_id",""))
	var who := "你" if subject == "player" else str(names.get(subject,"有人"))
	match str(memory.get("event_type","")):
		"player_gave_item","gift_received": return "%s在我需要時送我麵包" % who
		"player_stole_item","caught_stealing": return "%s偷走我的食物" % who
		"quest_completed": return "%s替我完成了委託" % who
		"npc_helped_npc": return "%s在危險中保護了我" % who
		"helped_npc": return "我在危險中幫了忙"
		"npc_argued": return "那次爭執"
		"npc_injury": return "我在林場受傷的那天"
		"trade_event": return "我們之前的交易"
		"small_talk": return "我們上次聊天"
	return "那件事"

func _pick(rng: RandomNumberGenerator, options: Variant) -> String:
	if not (options is Array) or options.is_empty(): return ""
	return str(options[rng.randi_range(0,options.size() - 1)])
