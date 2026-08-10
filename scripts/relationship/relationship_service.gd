class_name RelationshipService
extends RefCounted

const DEFAULT_RELATIONSHIP := {"affinity":0.0,"trust":0.0,"fear":0.0,"respect":0.0}

func apply_change(npc: Dictionary, target_id: String, changes: Dictionary) -> Dictionary:
	var relation: Dictionary = npc.get("relationships",{}).get(target_id,DEFAULT_RELATIONSHIP).duplicate(true)
	for key in changes:
		if key not in DEFAULT_RELATIONSHIP: continue
		relation[key] = clampf(float(relation.get(key,0.0)) + float(changes[key]),-100.0,100.0)
	npc["relationships"][target_id] = relation
	return relation.duplicate(true)
