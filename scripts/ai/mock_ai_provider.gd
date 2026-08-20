class_name MockAIProvider
extends RefCounted

func request_dialogue(context: Dictionary) -> Dictionary:
	var raw_profile = context.get("npc_profile",{})
	var profile: Dictionary = raw_profile if raw_profile is Dictionary else {}
	var name := str(profile.get("display_name","居民")).left(64)
	var mood := str(context.get("mood","Neutral")).to_lower()
	return {"dialogue":"我是%s。今天也能聽見村落的回音。" % name,"emotion":mood if mood in ["happy","neutral","sad","angry","afraid","tired"] else "neutral","intent":"small_talk"}
