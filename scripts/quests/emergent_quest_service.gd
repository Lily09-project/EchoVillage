class_name EmergentQuestService
extends RefCounted

## Procedural commissions that grow out of the simulation: clearing a
## distorted rumour, feeding a hungry villager, reconciling two villagers who
## fell out. Every generated quest is validated against the world (people,
## items and recipients exist; the task is achievable) and the same world
## state always yields the same offers.

const MAX_OFFERS := 3
const HUNGER_THRESHOLD := 60.0
const FEUD_THRESHOLD := -8.0
const RUMOR_HOLDERS := 2

## state: {"day", "npcs": {id: {display_name, needs, inventory, relationships}},
##         "rumors": rumour snapshot from RumorService, "player_inventory",
##         "item_ids": [...], "taken": [quest ids already active or completed],
##         "active": [active quest ids]}
func generate(state: Dictionary) -> Array:
	var offers: Array = []
	var npcs: Dictionary = state.get("npcs",{})
	var ids: Array = npcs.keys()
	ids.sort()
	var taken: Array = state.get("taken",[])
	var active: Array = state.get("active",[])
	var day := int(state.get("day",1))
	for candidate in _rumor_quests(state,npcs,day) + _hunger_quests(state,npcs,ids,day) + _feud_quests(npcs,ids,day):
		if offers.size() >= MAX_OFFERS: break
		# One commission per situation at a time; a finished one may come back on a later day.
		if str(candidate["id"]) in taken or _family_active(str(candidate.get("family","")),active): continue
		if validate(candidate,state): offers.append(candidate)
	return offers

func validate(quest: Dictionary, state: Dictionary) -> bool:
	var npcs: Dictionary = state.get("npcs",{})
	var items: Array = state.get("item_ids",[])
	if str(quest.get("id","")).is_empty() or str(quest.get("title","")).is_empty(): return false
	if not npcs.has(str(quest.get("giver_id",""))): return false
	var objectives: Array = quest.get("objectives",[])
	if objectives.is_empty(): return false
	for objective in objectives:
		match str(objective.get("kind","")):
			"talk_to_npc":
				if not npcs.has(str(objective.get("target_id",""))): return false
			"deliver_item":
				var item := str(objective.get("target_id",""))
				if item not in items or not npcs.has(str(objective.get("recipient_id",""))): return false
				if not _item_obtainable(item,int(objective.get("amount",1)),state): return false
			_:
				return false
	for effect in quest.get("effects",[]):
		match str(effect.get("kind","")):
			"relationship":
				if not npcs.has(str(effect.get("npc_id",""))) or not (npcs.has(str(effect.get("target_id",""))) or str(effect.get("target_id","")) == "player"): return false
			"debunk_rumor":
				if not _rumor_exists(str(effect.get("rumor_id","")),state): return false
			"feed":
				if not npcs.has(str(effect.get("npc_id",""))): return false
			_:
				return false
	return true

func _rumor_quests(state: Dictionary, npcs: Dictionary, day: int) -> Array:
	var result: Array = []
	for rumor in state.get("rumors",[]):
		var subject := str(rumor.get("subject_id",""))
		if bool(rumor.get("debunked",false)) or float(rumor.get("emotion",0.0)) >= 0.0 or not npcs.has(subject): continue
		var holders: Array = []
		var distorted := false
		for holder in rumor.get("holders",[]):
			if str(holder.get("id","")) == subject or str(holder.get("id","")) == str(rumor.get("origin_npc","")): continue
			holders.append(holder)
			if int(holder.get("version",0)) > 0: distorted = true
		if holders.size() < RUMOR_HOLDERS or not distorted: continue
		holders.sort_custom(func(a, b): return float(a["strength"]) > float(b["strength"]) or (float(a["strength"]) == float(b["strength"]) and str(a["id"]) < str(b["id"])))
		var objectives: Array = []
		var effects: Array = [{"kind":"debunk_rumor","rumor_id":str(rumor["id"])}]
		for holder in holders.slice(0,RUMOR_HOLDERS):
			var holder_id := str(holder["id"])
			objectives.append({"kind":"talk_to_npc","target_id":holder_id,"amount":1,"description":"向%s說明真相（詢問 Q）" % _name(holder_id,npcs)})
			effects.append({"kind":"relationship","npc_id":holder_id,"target_id":subject,"changes":{"trust":6.0}})
		var subject_name := _name(subject,npcs)
		result.append({
			"id":"emergent_rumor_%s_d%d" % [str(rumor["id"]),day],"family":"rumor:%s" % str(rumor["id"]),"emergent":true,
			"title":"替%s澄清流言" % subject_name,
			"description":"關於%s的傳聞越傳越離譜。找聽信傳聞的居民說明原委，還%s一個清白。" % [subject_name,subject_name],
			"giver_id":subject,"prerequisites":[],"objectives":objectives,
			"rewards":{"coin":4,"renown":2},"effects":effects,"source":{"rumor_id":str(rumor["id"])}
		})
	return result

func _hunger_quests(state: Dictionary, npcs: Dictionary, ids: Array, day: int) -> Array:
	var result: Array = []
	for npc_id in ids:
		var npc: Dictionary = npcs[npc_id]
		if float(npc.get("needs",{}).get("hunger",0.0)) < HUNGER_THRESHOLD: continue
		if int(npc.get("inventory",{}).get("bread",0)) > 0: continue
		result.append({
			"id":"emergent_feed_%s_d%d" % [npc_id,day],"family":"feed:%s" % npc_id,"emergent":true,
			"title":"送一份麵包給%s" % _name(str(npc_id),npcs),
			"description":"%s餓了一整天，手邊卻沒有食物。帶一份麵包給他吧。" % _name(str(npc_id),npcs),
			"giver_id":npc_id,"prerequisites":[],
			"objectives":[{"kind":"deliver_item","target_id":"bread","recipient_id":npc_id,"amount":1,"description":"把麵包交給%s（贈送 G）" % _name(str(npc_id),npcs)}],
			"rewards":{"coin":3,"renown":1},"effects":[{"kind":"feed","npc_id":npc_id},{"kind":"relationship","npc_id":npc_id,"target_id":"player","changes":{"affinity":4.0,"trust":2.0}}]
		})
	return result

func _feud_quests(npcs: Dictionary, ids: Array, day: int) -> Array:
	var result: Array = []
	for i in ids.size():
		for j in range(i + 1,ids.size()):
			var a := str(ids[i])
			var b := str(ids[j])
			var ab := float(npcs[a].get("relationships",{}).get(b,{}).get("trust",0.0))
			var ba := float(npcs[b].get("relationships",{}).get(a,{}).get("trust",0.0))
			if ab > FEUD_THRESHOLD or ba > FEUD_THRESHOLD: continue
			result.append({
				"id":"emergent_reconcile_%s_%s_d%d" % [a,b,day],"family":"reconcile:%s:%s" % [a,b],"emergent":true,
				"title":"調解%s與%s" % [_name(a,npcs),_name(b,npcs)],
				"description":"%s和%s鬧得很僵。分別聽聽兩人的說法，幫他們找回信任。" % [_name(a,npcs),_name(b,npcs)],
				"giver_id":a,"prerequisites":[],
				"objectives":[
					{"kind":"talk_to_npc","target_id":a,"amount":1,"description":"聽%s的說法（詢問 Q）" % _name(a,npcs)},
					{"kind":"talk_to_npc","target_id":b,"amount":1,"description":"聽%s的說法（詢問 Q）" % _name(b,npcs)}
				],
				"rewards":{"coin":5,"renown":2},
				"effects":[{"kind":"relationship","npc_id":a,"target_id":b,"changes":{"trust":10.0,"affinity":6.0}},{"kind":"relationship","npc_id":b,"target_id":a,"changes":{"trust":10.0,"affinity":6.0}}]
			})
	return result

func _item_obtainable(item: String, amount: int, state: Dictionary) -> bool:
	if int(state.get("player_inventory",{}).get(item,0)) >= amount: return true
	for npc in state.get("npcs",{}).values():
		if int(npc.get("inventory",{}).get(item,0)) >= amount: return true
	return false

func _rumor_exists(rumor_id: String, state: Dictionary) -> bool:
	for rumor in state.get("rumors",[]):
		if str(rumor.get("id","")) == rumor_id: return true
	return false

func _family_active(family: String, active: Array) -> bool:
	if family.is_empty(): return false
	for quest_id in active:
		if family_of(str(quest_id)) == family: return true
	return false

## The situation a commission id belongs to, e.g. "feed:alice".
func family_of(quest_id: String) -> String:
	var cut := quest_id.rfind("_d")
	if not quest_id.begins_with("emergent_") or cut < 0: return ""
	var base := quest_id.substr(0,cut)
	if base.begins_with("emergent_rumor_"): return "rumor:" + base.trim_prefix("emergent_rumor_")
	if base.begins_with("emergent_feed_"): return "feed:" + base.trim_prefix("emergent_feed_")
	if base.begins_with("emergent_reconcile_"):
		var pair := base.trim_prefix("emergent_reconcile_").split("_")
		return "reconcile:%s:%s" % [pair[0],pair[1]] if pair.size() == 2 else ""
	return ""

func _name(npc_id: String, npcs: Dictionary) -> String:
	return str(npcs.get(npc_id,{}).get("display_name",npc_id))
