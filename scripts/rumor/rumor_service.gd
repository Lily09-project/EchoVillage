class_name RumorService
extends RefCounted

## Rumours: memories that travel between villagers.
##
## A rumour starts from one villager's important memory. Once per gossip round
## every holder may retell it to villagers they trust; each retelling loses
## strength and credibility and may distort the story into a more dramatic
## version. A villager hears a given rumour at most once and weak rumours stop
## travelling, so propagation always terminates. Every retelling is recorded,
## so the chain from any listener back to the original event can be traced.
## All randomness comes from a seeded generator: the same world, day and seed
## always produce the same spread.

const TRUST_THRESHOLD := 10.0
const STRENGTH_DECAY := 0.72
const CREDIBILITY_DECAY := 0.88
const DISTORTION_CREDIBILITY := 0.8
const DISTORTION_CHANCE := 0.3
const MIN_STRENGTH := 12.0
const MAX_RUMORS := 12
const MAX_TRANSMISSIONS := 64
const MIN_SOURCE_IMPORTANCE := 30

## Story versions per memory kind, from faithful to most distorted.
## Placeholders: {subject} {object}.
const VERSIONS := {
	"player_stole_item":["{subject}從{object}那裡拿走了一份麵包","{subject}偷了{object}一整籃麵包","{subject}是專門在市集偷東西的慣犯"],
	"player_gave_item":["{subject}送了{object}一份麵包","{subject}在{object}最需要時伸出援手","{subject}把自己的糧食全分給了村民"],
	"npc_argued":["{subject}和{object}起了口角","{subject}和{object}當街大吵一架","{subject}和{object}已經互不往來"],
	"npc_helped_npc":["{subject}在危險中幫了{object}","{subject}冒險救了{object}","{subject}一個人擊退了危險、救下{object}"],
	"npc_injury":["{object}在林場受了傷","{object}傷得不輕，好幾天不能工作","{object}差點在林場出了大事"],
	"quest_completed":["{subject}完成了村民的委託","{subject}替村子解決了大麻煩","{subject}是村裡最可靠的人"],
}

var rumors: Array = []
var sequence := 0

func reset() -> void:
	rumors.clear()
	sequence = 0

func is_rumor_worthy(memory: Dictionary) -> bool:
	return VERSIONS.has(str(memory.get("event_type",""))) and int(memory.get("importance",0)) >= MIN_SOURCE_IMPORTANCE and not str(memory.get("event_type","")).begins_with("heard_")

## Start a rumour from a villager's memory. Returns the rumour, or {} if the
## memory is not rumour-worthy or the same event is already circulating.
func seed_from_memory(npc_id: String, memory: Dictionary, day: int) -> Dictionary:
	if npc_id.is_empty() or not is_rumor_worthy(memory): return {}
	var origin_key := "%s|%s|%s|%d" % [str(memory.get("event_type","")),str(memory.get("subject_id","")),str(memory.get("object_id","")),day]
	for value in rumors:
		if str(value.get("origin_key","")) == origin_key: return {}
	sequence += 1
	var rumor := {
		"id":"rumor_%d" % sequence,
		"origin_key":origin_key,
		"kind":str(memory.get("event_type","")),
		"subject_id":str(memory.get("subject_id","")),
		"object_id":str(memory.get("object_id","")),
		"origin_npc":npc_id,
		"origin_memory":str(memory.get("id","")),
		"origin_day":day,
		"emotion":clampf(float(memory.get("emotional_value",0.0)),-100.0,100.0),
		"importance":int(memory.get("importance",0)),
		"debunked":false,
		"holders":{npc_id:{"strength":100.0,"credibility":1.0,"version":0,"heard_from":"","day":day,"hops":0}},
		"transmissions":[]
	}
	rumors.append(rumor)
	while rumors.size() > MAX_RUMORS: rumors.pop_front()
	return rumor

func find(rumor_id: String) -> Dictionary:
	for value in rumors:
		if str(value.get("id","")) == rumor_id: return value
	return {}

## Text of one version of a rumour with names filled in.
func describe(rumor: Dictionary, version: int, names: Dictionary) -> String:
	var versions: Array = VERSIONS.get(str(rumor.get("kind","")),["{subject}的事"])
	var template := str(versions[clampi(version,0,versions.size() - 1)])
	return template.replace("{subject}",_name(str(rumor.get("subject_id","")),names)).replace("{object}",_name(str(rumor.get("object_id","")),names))

## One gossip round. `npcs` maps id → villager (needs "relationships" and an
## optional "personality.sociability"). Returns the retellings that happened.
func propagate_round(npcs: Dictionary, day: int, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed * 1000003 + day * 7919 + sequence)
	var ids: Array = npcs.keys()
	ids.sort()
	var happened: Array = []
	for rumor in rumors:
		if bool(rumor.get("debunked",false)): continue
		var holder_ids: Array = rumor["holders"].keys()
		holder_ids.sort()
		for from_id in holder_ids:
			# Only villagers who already held the rumour before this round retell it.
			if int(rumor["holders"][from_id].get("day",day)) >= day and int(rumor["holders"][from_id].get("hops",0)) > 0: continue
			for to_id in ids:
				if to_id == from_id or rumor["holders"].has(to_id): continue
				if str(to_id) == str(rumor.get("subject_id","")): continue
				var chance := transmission_chance(npcs.get(from_id,{}),str(to_id),float(rumor["holders"][from_id]["strength"]))
				if chance <= 0.0: continue
				if rng.randf() >= chance: continue
				var transmission := transmit(rumor,str(from_id),str(to_id),day,rng)
				if not transmission.is_empty(): happened.append(transmission)
	return happened

## Probability that `source` retells a rumour of the given strength to `target_id`.
## Zero when trust is below the threshold.
func transmission_chance(source: Dictionary, target_id: String, strength: float) -> float:
	var relation: Dictionary = source.get("relationships",{}).get(target_id,{})
	var trust := float(relation.get("trust",0.0))
	if trust < TRUST_THRESHOLD or strength < MIN_STRENGTH: return 0.0
	var sociability := float(source.get("personality",{}).get("sociability",0.5))
	var base := clampf(0.15 + trust / 100.0 + float(relation.get("affinity",0.0)) / 200.0,0.0,0.9)
	return clampf(base * (0.5 + sociability) * strength / 100.0,0.0,0.95)

## Record that `from_id` told `to_id`. Strength and credibility decay; the
## story may be distorted into the next, more dramatic version.
func transmit(rumor: Dictionary, from_id: String, to_id: String, day: int, rng: RandomNumberGenerator) -> Dictionary:
	if not rumor.get("holders",{}).has(from_id) or rumor["holders"].has(to_id): return {}
	if rumor.get("transmissions",[]).size() >= MAX_TRANSMISSIONS: return {}
	var source: Dictionary = rumor["holders"][from_id]
	var strength := float(source.get("strength",0.0)) * STRENGTH_DECAY
	if strength < MIN_STRENGTH: return {}
	var credibility := float(source.get("credibility",1.0)) * CREDIBILITY_DECAY
	var version := int(source.get("version",0))
	var distorted: bool = rng.randf() < DISTORTION_CHANCE and version < VERSIONS.get(str(rumor.get("kind","")),[]).size() - 1
	if distorted:
		version += 1
		credibility *= DISTORTION_CREDIBILITY
	rumor["holders"][to_id] = {"strength":strength,"credibility":credibility,"version":version,"heard_from":from_id,"day":day,"hops":int(source.get("hops",0)) + 1}
	var transmission := {"rumor_id":str(rumor["id"]),"from":from_id,"to":to_id,"day":day,"strength":strength,"credibility":credibility,"version":version,"distorted":distorted}
	rumor["transmissions"].append(transmission)
	return transmission.duplicate(true)

## The chain of tellers from the original witness to `npc_id` (inclusive).
func trace(rumor_id: String, npc_id: String) -> Array:
	var rumor := find(rumor_id)
	if rumor.is_empty() or not rumor["holders"].has(npc_id): return []
	var chain: Array = []
	var current := npc_id
	var guard := 0
	while not current.is_empty() and guard <= rumor["holders"].size():
		chain.push_front(current)
		current = str(rumor["holders"].get(current,{}).get("heard_from",""))
		guard += 1
	return chain

func debunk(rumor_id: String) -> bool:
	var rumor := find(rumor_id)
	if rumor.is_empty() or bool(rumor.get("debunked",false)): return false
	rumor["debunked"] = true
	return true

## Snapshot for the UI: rumours newest first, with readable versions per holder.
func snapshot(names: Dictionary) -> Array:
	var result: Array = []
	for index in range(rumors.size() - 1,-1,-1):
		var rumor: Dictionary = rumors[index]
		var holders: Array = []
		var holder_ids: Array = rumor["holders"].keys()
		holder_ids.sort()
		for holder_id in holder_ids:
			var holder: Dictionary = rumor["holders"][holder_id]
			holders.append({"id":holder_id,"name":_name(str(holder_id),names),"strength":float(holder["strength"]),"credibility":float(holder["credibility"]),"version":int(holder["version"]),"heard_from":str(holder["heard_from"]),"text":describe(rumor,int(holder["version"]),names)})
		result.append({"id":rumor["id"],"kind":rumor["kind"],"subject_id":rumor["subject_id"],"origin_npc":rumor["origin_npc"],"origin_day":rumor["origin_day"],"emotion":rumor["emotion"],"debunked":rumor["debunked"],"original":describe(rumor,0,names),"holders":holders,"transmissions":rumor["transmissions"].duplicate(true)})
	return result

func serialize() -> Dictionary:
	return {"schema_version":1,"sequence":sequence,"rumors":rumors.duplicate(true)}

func validate_state(value: Variant) -> bool:
	if not (value is Dictionary): return false
	var state: Dictionary = value
	if not (state.get("rumors",[]) is Array) or state.get("rumors",[]).size() > MAX_RUMORS: return false
	if not _bounded_integer(state.get("sequence",0),0,1000000000): return false
	for rumor in state.get("rumors",[]):
		if not (rumor is Dictionary): return false
		for key in ["id","kind","subject_id","object_id","origin_npc","origin_memory","origin_key"]:
			if not (rumor.get(key) is String): return false
		if not VERSIONS.has(rumor["kind"]): return false
		if not _bounded_integer(rumor.get("origin_day"),1,1000000): return false
		if not _bounded_integer(rumor.get("importance"),0,1000000000): return false
		if not _bounded_number(rumor.get("emotion"),-100.0,100.0) or not (rumor.get("debunked") is bool): return false
		if not (rumor.get("holders") is Dictionary) or rumor["holders"].size() > 64: return false
		if not (rumor.get("transmissions") is Array) or rumor["transmissions"].size() > MAX_TRANSMISSIONS: return false
		for holder_id in rumor["holders"]:
			if not (holder_id is String): return false
			var holder = rumor["holders"][holder_id]
			if not (holder is Dictionary): return false
			if not _bounded_number(holder.get("strength"),0.0,100.0) or not _bounded_number(holder.get("credibility"),0.0,1.0): return false
			if not _bounded_integer(holder.get("version"),0,VERSIONS[rumor["kind"]].size() - 1): return false
			if not _bounded_integer(holder.get("day"),1,1000000) or not _bounded_integer(holder.get("hops"),0,64): return false
			if not (holder.get("heard_from") is String): return false
		for transmission in rumor["transmissions"]:
			if not (transmission is Dictionary): return false
			for key in ["rumor_id","from","to"]:
				if not (transmission.get(key) is String): return false
			if not _bounded_integer(transmission.get("day"),1,1000000): return false
			if not _bounded_integer(transmission.get("version"),0,VERSIONS[rumor["kind"]].size() - 1): return false
			if not _bounded_number(transmission.get("strength"),0.0,100.0) or not _bounded_number(transmission.get("credibility"),0.0,1.0): return false
			if not (transmission.get("distorted") is bool): return false
	return true

func _bounded_number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _bounded_number(value,float(minimum),float(maximum)) and float(value) == floor(float(value))

func load_state(value: Variant) -> bool:
	if not validate_state(value): return false
	rumors = value.get("rumors",[]).duplicate(true)
	sequence = int(value.get("sequence",rumors.size()))
	return true

func _name(actor_id: String, names: Dictionary) -> String:
	if actor_id == "player": return "玩家"
	if actor_id == "world" or actor_id.is_empty(): return "某人"
	return str(names.get(actor_id,actor_id))
