extends RefCounted

## Regression tests for long-session and corrupted-save robustness: bounded
## completed-quest history, rumour and story save validation, debunked rumours
## and the causal timeline surviving a full day of NPC decision logs.

const RumorServiceScript = preload("res://scripts/rumor/rumor_service.gd")
const QuestServiceScript = preload("res://scripts/services/quest_service.gd")

static func _rumor_service() -> RumorService:
	var service = RumorServiceScript.new()
	service.seed_from_memory("bob",{"id":"memory_robust","event_type":"player_stole_item","subject_id":"player","object_id":"bob","emotional_value":-32.0,"importance":70},1)
	return service

## Before the fix a holder without credibility (or a rumour without holders)
## loaded fine and then broke snapshot() on every rumour-panel refresh.
static func rumor_state_rejects_missing_fields() -> bool:
	var state: Dictionary = _rumor_service().serialize()
	if not RumorServiceScript.new().load_state(JSON.parse_string(JSON.stringify(state))): return false
	var no_holders: Dictionary = state.duplicate(true)
	no_holders["rumors"][0].erase("holders")
	var no_credibility: Dictionary = state.duplicate(true)
	no_credibility["rumors"][0]["holders"]["bob"].erase("credibility")
	var bad_transmission: Dictionary = state.duplicate(true)
	bad_transmission["rumors"][0]["transmissions"] = ["oops"]
	var restored = RumorServiceScript.new()
	return not restored.load_state(no_holders) and not restored.load_state(no_credibility) and not restored.load_state(bad_transmission)

## share_memory() calls transmit() directly; a debunked rumour must stay quiet.
static func debunked_rumor_is_not_retold() -> bool:
	var service := _rumor_service()
	var rumor_id := str(service.rumors[0]["id"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	if service.transmit(service.find(rumor_id),"bob","player",2,rng).size() != 0: return false
	if service.transmit(service.find(rumor_id),"bob","alice",2,rng).is_empty(): return false
	service.debunk(rumor_id)
	return service.transmit(service.find(rumor_id),"bob","charlie",3,rng).is_empty() and not service.find(rumor_id)["holders"].has("charlie")

## Completed generated commissions used to grow without limit until the save
## validator (max 512) rejected the save.
static func completed_quests_stay_bounded() -> bool:
	var definitions := {"forest_echo":{"objectives":[{"kind":"talk","target_id":"alice","amount":1}]}}
	for index in 600:
		definitions["emergent_feed_alice_d%d" % index] = {"objectives":[{"kind":"deliver","target_id":"bread","amount":1}]}
	var service = QuestServiceScript.new(definitions)
	var active := {}
	var completed: Array = []
	service.accept(active,completed,"forest_echo")
	service.notify(active,completed,"talk","alice")
	for index in 600:
		var quest_id := "emergent_feed_alice_d%d" % index
		if not bool(service.accept(active,completed,quest_id).get("ok",false)): return false
		var done: Array = service.notify(active,completed,"deliver","bread")["completed"]
		if done.size() != 1 or str(done[0]) != quest_id: return false
	var emergent := completed.filter(func(id): return str(id).begins_with("emergent_"))
	return "forest_echo" in completed and emergent.size() == QuestServiceScript.MAX_EMERGENT_COMPLETED and completed.has("emergent_feed_alice_d599") and not completed.has("emergent_feed_alice_d0") and completed.size() < 512

static func story_state_requires_choices_for_active_arcs() -> bool:
	GameManager.new_game()
	GameManager.interact("bob","steal_food")
	var state: Dictionary = GameManager.story_service.serialize()
	if not state.get("arcs",{}).has("bread_rumor"): return false
	if not GameManager.story_service.validate_state(state): return false
	var broken: Dictionary = state.duplicate(true)
	broken["arcs"]["bread_rumor"].erase("choices_made")
	return not GameManager.story_service.validate_state(broken)

## About 720 decision logs a day used to evict every causal event from the
## 160-event timeline before midnight, so the village journal came out empty.
static func timeline_keeps_causal_events_through_a_day() -> bool:
	GameManager.new_game()
	GameManager.interact("alice","give_bread")
	var day := GameTime.day
	if bool(GameManager.journal_for_day(day).get("empty",true)): return false
	for index in 800:
		GameManager.add_log("艾莉絲 選擇 Action Wander，分數 %d.0。" % (index % 50))
	if GameManager.timeline_events.size() > 160: return false
	var newest: Dictionary = GameManager.timeline_events.back()
	return not bool(GameManager.journal_for_day(day).get("empty",true)) and str(newest.get("message","")).contains("Wander")
