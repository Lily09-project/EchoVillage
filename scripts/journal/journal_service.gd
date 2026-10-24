class_name JournalService
extends RefCounted

## Writes a short story of one day from that day's causal events and rumour
## retellings. Only events from the requested day are cited, and every
## sentence records which event it came from.

const MAX_SENTENCES := 5
const PRIORITY := {"story":0,"world":1,"quest":2,"memory":3,"relationship":4,"economy":5,"location":6}
const RELATIONSHIP_LABELS := {"trust":"信任","affinity":"好感","fear":"恐懼","respect":"尊敬"}

func compose(day: int, events: Array, transmissions: Array, names: Dictionary, rumor_texts: Dictionary = {}) -> Dictionary:
	var candidates: Array = []
	for value in events:
		if not (value is Dictionary): continue
		var event: Dictionary = value
		if int(event.get("day",-1)) != day: continue
		var kind := str(event.get("effect_kind",event.get("category","")))
		if not PRIORITY.has(kind): continue
		var sentence := _sentence(event,kind,names)
		if sentence.is_empty(): continue
		candidates.append({"priority":int(PRIORITY[kind]),"order":candidates.size(),"text":sentence,"cite":str(event.get("id",""))})
	for value in transmissions:
		if not (value is Dictionary) or int(value.get("day",-1)) != day: continue
		var text := str(rumor_texts.get(str(value.get("rumor_id","")),"一則傳聞"))
		var sentence := "%s把「%s」告訴了%s%s。" % [_name(str(value.get("from","")),names),text,_name(str(value.get("to","")),names),"，還添油加醋了一番" if bool(value.get("distorted",false)) else ""]
		candidates.append({"priority":3,"order":candidates.size(),"text":sentence,"cite":"%s:%s>%s" % [str(value.get("rumor_id","")),str(value.get("from","")),str(value.get("to",""))]})
	candidates.sort_custom(func(a, b): return a["priority"] < b["priority"] or (a["priority"] == b["priority"] and a["order"] < b["order"]))
	var chosen := candidates.slice(0,MAX_SENTENCES)
	if chosen.is_empty():
		return {"day":day,"empty":true,"text":"第 %d 天，村裡風平浪靜，沒有值得記下的事。" % day,"cited":[]}
	var sentences: Array = []
	var cited: Array = []
	for item in chosen:
		sentences.append(str(item["text"]))
		cited.append(str(item["cite"]))
	var extra := candidates.size() - chosen.size()
	var text := "第 %d 天。%s" % [day,"".join(sentences)]
	if extra > 0: text += "此外還有 %d 件小事。" % extra
	return {"day":day,"empty":false,"text":text,"cited":cited}

func _sentence(event: Dictionary, kind: String, names: Dictionary) -> String:
	var effect: Dictionary = event.get("effect",{}) if event.get("effect",{}) is Dictionary else {}
	match kind:
		"relationship":
			var changes: Dictionary = effect.get("changes",{})
			var parts: Array = []
			for key in ["trust","affinity","fear","respect"]:
				if changes.has(key) and absf(float(changes[key])) >= 1.0:
					parts.append("%s%s" % [RELATIONSHIP_LABELS[key],"上升" if float(changes[key]) > 0.0 else "下降"])
			if parts.is_empty(): return ""
			return "%s對%s的%s。" % [_name(str(effect.get("npc_id","")),names),_name(str(effect.get("target_id","")),names),"、".join(parts)]
		"memory":
			if int(effect.get("importance",0)) < 30: return ""
			return "%s記住了一件事：%s。" % [_name(str(effect.get("npc_id","")),names),_memory_label(str(effect.get("memory_type","")))]
		"story":
			return "在「%s」的故事裡，選擇了「%s」。" % [str(effect.get("arc_title","故事")),str(effect.get("choice_label","選擇"))]
	var message := str(event.get("message","")).strip_edges()
	if message.is_empty(): return ""
	return message if message.ends_with("。") else message + "。"

func _memory_label(kind: String) -> String:
	var labels := {"player_gave_item":"收到玩家的贈禮","player_stole_item":"目睹玩家偷竊","npc_argued":"與人爭執","npc_helped_npc":"在危險中獲救","helped_npc":"在危險中助人","npc_injury":"在林場受傷","quest_completed":"委託完成"}
	if kind.begins_with("heard_"): return "聽說了一則傳聞"
	return str(labels.get(kind,"一段經歷"))

func _name(actor_id: String, names: Dictionary) -> String:
	if actor_id == "player": return "玩家"
	return str(names.get(actor_id,actor_id if not actor_id.is_empty() else "某人"))
