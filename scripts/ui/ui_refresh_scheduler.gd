class_name UiRefreshScheduler
extends RefCounted

const TIME := 1 << 0
const PLAYER := 1 << 1
const WORLD := 1 << 2
const NPC := 1 << 3
const QUEST := 1 << 4
const PROGRESSION := 1 << 5
const LOG := 1 << 6
const CONTEXT := 1 << 7
const DEBUG := 1 << 8
const ALL := TIME | PLAYER | WORLD | NPC | QUEST | PROGRESSION | LOG | CONTEXT | DEBUG

var _pending_mask := 0
var _reasons: Array[String] = []
var _flushes := 0
var _requests := 0
var _section_counts: Dictionary = {}

func request(mask: int, reason: String = "") -> void:
	_requests += 1
	_pending_mask |= mask
	if reason != "":
		_reasons.append(reason)

func consume() -> Dictionary:
	if _pending_mask == 0:
		return {"mask":0,"reasons":[]}
	var mask := _pending_mask
	var reasons := _reasons.duplicate()
	_pending_mask = 0
	_reasons.clear()
	_flushes += 1
	for section in [TIME,PLAYER,WORLD,NPC,QUEST,PROGRESSION,LOG,CONTEXT,DEBUG]:
		if mask & section:
			_section_counts[section] = int(_section_counts.get(section,0)) + 1
	return {"mask":mask,"reasons":reasons}

func metrics() -> Dictionary:
	return {
		"flushes":_flushes,
		"section_counts":_section_counts.duplicate(true),
		"coalesced_requests":maxi(0,_requests - _flushes)
	}
