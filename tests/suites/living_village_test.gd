extends RefCounted

## Pure-logic tests for the rumour network, emergent commissions, grammar
## dialogue and the village journal. None of these touch the scene tree.

const RumorServiceScript = preload("res://scripts/rumor/rumor_service.gd")
const EmergentQuestServiceScript = preload("res://scripts/quests/emergent_quest_service.gd")
const DialogueGrammarScript = preload("res://scripts/dialogue/dialogue_grammar.gd")
const JournalServiceScript = preload("res://scripts/journal/journal_service.gd")

static func _village(trust: float) -> Dictionary:
	var ids := ["alice","bob","charlie","diana","eric"]
	var npcs := {}
	for id in ids:
		var relationships := {}
		for other in ids:
			if other != id: relationships[other] = {"trust":trust,"affinity":trust * 0.5,"fear":0.0,"respect":0.0}
		npcs[id] = {"id":id,"display_name":id.capitalize(),"relationships":relationships,"personality":{"sociability":0.8}}
	return npcs

static func _memory(kind: String, subject: String, object: String, emotion: float, importance: int) -> Dictionary:
	return {"id":"memory_test_%s" % kind,"event_type":kind,"subject_id":subject,"object_id":object,"emotional_value":emotion,"importance":importance}

static func _spread(seed: int, rounds: int, trust: float = 40.0):
	var service = RumorServiceScript.new()
	var npcs := _village(trust)
	service.seed_from_memory("bob",_memory("player_stole_item","player","bob",-32.0,70),1)
	var all: Array = []
	for day in range(1,rounds + 1): all += service.propagate_round(npcs,day,seed)
	return {"service":service,"transmissions":all}

static func rumor_spread_is_deterministic() -> bool:
	var first = _spread(7,6)
	var second = _spread(7,6)
	var other = _spread(8,6)
	if first["transmissions"].is_empty(): return false
	if JSON.stringify(first["service"].serialize()) != JSON.stringify(second["service"].serialize()): return false
	return JSON.stringify(first["transmissions"]) == JSON.stringify(second["transmissions"]) and JSON.stringify(first["transmissions"]) != JSON.stringify(other["transmissions"])

static func rumor_requires_trust() -> bool:
	var low = _spread(7,10,5.0)
	var service = RumorServiceScript.new()
	var village := _village(9.9)
	if service.transmission_chance(village["alice"],"bob",100.0) != 0.0: return false
	if service.transmission_chance(_village(10.0)["alice"],"bob",100.0) <= 0.0: return false
	return low["transmissions"].is_empty()

static func rumor_weakens_and_terminates() -> bool:
	var result = _spread(11,40,90.0)
	var service = result["service"]
	var rumor: Dictionary = service.rumors[0]
	var seen := {}
	for transmission in result["transmissions"]:
		var to_id := str(transmission["to"])
		if seen.has(to_id): return false  # nobody hears the same rumour twice
		seen[to_id] = true
		var teller: Dictionary = rumor["holders"][transmission["from"]]
		if float(transmission["strength"]) >= float(teller["strength"]): return false
	# The subject (the player) is not a villager; at most four listeners exist.
	if result["transmissions"].size() > 4: return false
	# Once everyone has heard it, further rounds are silent.
	return service.propagate_round(_village(90.0),41,11).is_empty()

static func rumor_chain_traces_to_origin() -> bool:
	var result = _spread(3,8)
	var service = result["service"]
	var rumor: Dictionary = service.rumors[0]
	if rumor["holders"].size() < 3: return false
	for holder_id in rumor["holders"]:
		var chain: Array = service.trace(str(rumor["id"]),str(holder_id))
		if chain.is_empty() or str(chain[0]) != "bob" or str(chain[-1]) != str(holder_id): return false
		for index in range(1,chain.size()):
			if str(rumor["holders"][chain[index]]["heard_from"]) != str(chain[index - 1]): return false
	return service.trace(str(rumor["id"]),"nobody").is_empty()

static func rumor_distortion_lowers_credibility() -> bool:
	var result = _spread(5,10,90.0)
	var rumor: Dictionary = result["service"].rumors[0]
	var distorted_seen := false
	for transmission in result["transmissions"]:
		var teller: Dictionary = rumor["holders"][transmission["from"]]
		if bool(transmission["distorted"]):
			distorted_seen = true
			if int(transmission["version"]) != int(teller["version"]) + 1: return false
		if float(transmission["credibility"]) >= float(teller["credibility"]): return false
	return distorted_seen

static func rumor_state_validation() -> bool:
	var service = _spread(7,4)["service"]
	var state: Dictionary = service.serialize()
	var restored = RumorServiceScript.new()
	if not restored.load_state(state.duplicate(true)): return false
	if JSON.stringify(restored.serialize()) != JSON.stringify(state): return false
	var broken: Dictionary = state.duplicate(true)
	broken["rumors"][0]["holders"]["bob"]["strength"] = 500.0
	var unknown: Dictionary = state.duplicate(true)
	unknown["rumors"][0]["kind"] = "made_up"
	if not service.seed_from_memory("alice",_memory("small_talk","player","alice",2.0,12),1).is_empty(): return false
	return not restored.load_state(broken) and not restored.load_state(unknown) and not restored.load_state("nope")

static func _quest_state(bread_available: bool) -> Dictionary:
	var npcs := {}
	for id in ["alice","bob","charlie"]:
		npcs[id] = {"display_name":id.capitalize(),"needs":{"hunger":20.0},"inventory":{"bread":0},"relationships":{}}
	npcs["alice"]["needs"]["hunger"] = 85.0
	npcs["bob"]["relationships"]["charlie"] = {"trust":-12.0}
	npcs["charlie"]["relationships"]["bob"] = {"trust":-9.0}
	if bread_available: npcs["charlie"]["inventory"]["bread"] = 2
	var rumor := {"id":"rumor_1","subject_id":"bob","origin_npc":"charlie","emotion":-10.0,"debunked":false,"holders":[
		{"id":"charlie","strength":100.0,"version":0},{"id":"alice","strength":72.0,"version":1},{"id":"eric","strength":50.0,"version":1}]}
	npcs["eric"] = {"display_name":"Eric","needs":{"hunger":10.0},"inventory":{},"relationships":{}}
	return {"day":3,"npcs":npcs,"rumors":[rumor],"player_inventory":{"bread":0},"item_ids":["bread","herb"],"taken":[],"active":[]}

static func emergent_quests_reference_real_things() -> bool:
	var service = EmergentQuestServiceScript.new()
	var state := _quest_state(true)
	var offers: Array = service.generate(state)
	var families := []
	for offer in offers:
		if not service.validate(offer,state): return false
		families.append(service.family_of(str(offer["id"])))
		for objective in offer["objectives"]:
			if objective.has("recipient_id") and not state["npcs"].has(str(objective["recipient_id"])): return false
			if str(objective["kind"]) == "talk_to_npc" and not state["npcs"].has(str(objective["target_id"])): return false
	return offers.size() == 3 and "rumor:rumor_1" in families and "feed:alice" in families and "reconcile:bob:charlie" in families

static func emergent_quests_are_deterministic() -> bool:
	var service = EmergentQuestServiceScript.new()
	return JSON.stringify(service.generate(_quest_state(true))) == JSON.stringify(service.generate(_quest_state(true)))

static func emergent_quests_skip_impossible_or_duplicate() -> bool:
	var service = EmergentQuestServiceScript.new()
	var no_bread: Array = service.generate(_quest_state(false))
	for offer in no_bread:
		if service.family_of(str(offer["id"])) == "feed:alice": return false
	var state := _quest_state(true)
	state["active"] = ["emergent_feed_alice_d1"]
	for offer in service.generate(state):
		if service.family_of(str(offer["id"])) == "feed:alice": return false
	var bogus := {"id":"emergent_x","title":"x","giver_id":"ghost","objectives":[{"kind":"talk_to_npc","target_id":"alice"}],"effects":[]}
	var bad_item := {"id":"emergent_y","title":"y","giver_id":"alice","objectives":[{"kind":"deliver_item","target_id":"gold","recipient_id":"alice","amount":1}],"effects":[]}
	return not service.validate(bogus,state) and not service.validate(bad_item,state) and service.family_of("forest_echo") == ""

static func _grammar():
	var grammar = DialogueGrammarScript.new()
	var file := FileAccess.open("res://data/dialogue/grammar.json",FileAccess.READ)
	if file == null or not grammar.configure(JSON.parse_string(file.get_as_text())): return null
	return grammar

static func dialogue_lines_are_complete_and_short() -> bool:
	var grammar = _grammar()
	if grammar == null: return false
	var moods := ["Happy","Neutral","Sad","Angry","Afraid","Tired"]
	var tones := ["溫暖務實","沉穩保守","健談好奇","平靜關懷","簡短直接"]
	var memories := [[],[_memory("player_gave_item","player","alice",20.0,45)],[_memory("player_stole_item","player","alice",-32.0,70)]]
	var rumor_options := [[],[{"id":"rumor_1","text":"玩家偷了鮑伯一整籃麵包","teller_id":"charlie","credibility":0.5}]]
	var seed := 0
	for mood in moods:
		for tone in tones:
			for memory_list in memories:
				for rumors in rumor_options:
					seed += 1
					var npc := {"id":"alice","mood":mood,"needs":{"hunger":80.0 if seed % 3 == 0 else 10.0,"energy":20.0 if seed % 5 == 0 else 90.0},"memories":memory_list,"dialogue_profile":{"tone":tone,"topics":["草藥","森林"]}}
					var line: Dictionary = grammar.generate(npc,{"names":{"charlie":"查理","player":"玩家"},"rumors":rumors},seed)
					var text := str(line["text"])
					if text.is_empty() or text.contains("{") or text.contains("}") or text.length() > grammar.max_length: return false
	return true

static func dialogue_cites_only_known_memories_and_rumours() -> bool:
	var grammar = _grammar()
	if grammar == null: return false
	var memory := _memory("player_stole_item","player","alice",-32.0,70)
	var npc := {"id":"alice","mood":"Angry","needs":{},"memories":[memory],"dialogue_profile":{"tone":"簡短直接","topics":[]}}
	var line: Dictionary = grammar.generate(npc,{"names":{},"rumors":[]},4)
	if line["references"]["memories"] != [memory["id"]] or not str(line["text"]).contains("偷走"): return false
	var listener := {"id":"diana","mood":"Neutral","needs":{},"memories":[],"dialogue_profile":{"tone":"平靜關懷","topics":["草藥"]}}
	var heard := [{"id":"rumor_9","text":"鮑伯和查理當街大吵一架","teller_id":"charlie","credibility":0.9}]
	var rumor_line: Dictionary = grammar.generate(listener,{"names":{"charlie":"查理"},"rumors":heard},4)
	if rumor_line["references"]["rumors"] != ["rumor_9"] or not str(rumor_line["text"]).contains("鮑伯和查理當街大吵一架"): return false
	var quiet: Dictionary = grammar.generate(listener,{"names":{},"rumors":[]},4)
	return quiet["references"]["memories"].is_empty() and quiet["references"]["rumors"].is_empty()

static func dialogue_is_deterministic() -> bool:
	var grammar = _grammar()
	if grammar == null: return false
	var npc := {"id":"bob","mood":"Happy","needs":{},"memories":[],"dialogue_profile":{"tone":"沉穩保守","topics":["農事","天氣","收成"]}}
	var texts := {}
	for seed in range(12): texts[str(grammar.generate(npc,{},seed)["text"])] = true
	return grammar.generate(npc,{},42)["text"] == grammar.generate(npc,{},42)["text"] and texts.size() > 1

static func journal_cites_only_that_day() -> bool:
	var journal = JournalServiceScript.new()
	var events := [
		{"id":"echo_1","day":1,"effect_kind":"memory","effect":{"npc_id":"alice","memory_type":"player_gave_item","importance":45}},
		{"id":"echo_2","day":2,"effect_kind":"relationship","effect":{"npc_id":"bob","target_id":"player","changes":{"trust":-25.0}}},
		{"id":"echo_3","day":2,"category":"world","message":"世界事件開始：雨天"},
		{"id":"echo_4","day":3,"effect_kind":"story","effect":{"arc_title":"故事","choice_label":"道歉"}}
	]
	var transmissions := [{"rumor_id":"rumor_1","from":"bob","to":"charlie","day":2,"distorted":true},{"rumor_id":"rumor_1","from":"charlie","to":"alice","day":3,"distorted":false}]
	var entry: Dictionary = journal.compose(2,events,transmissions,{"bob":"鮑伯","charlie":"查理"},{"rumor_1":"玩家偷了麵包"})
	if bool(entry["empty"]): return false
	for cite in entry["cited"]:
		if cite not in ["echo_2","echo_3","rumor_1:bob>charlie"]: return false
	return entry["cited"].size() == 3 and str(entry["text"]).contains("第 2 天") and str(entry["text"]).contains("添油加醋")

static func journal_has_an_empty_state() -> bool:
	var journal = JournalServiceScript.new()
	var entry: Dictionary = journal.compose(5,[{"id":"echo_1","day":4,"category":"world","message":"雨"}],[],{})
	return bool(entry["empty"]) and entry["cited"].is_empty() and str(entry["text"]).contains("風平浪靜")
