extends RefCounted

static func run() -> bool:
	var script = load("res://scripts/ui/ui_refresh_scheduler.gd")
	if script == null:
		return false
	var scheduler = script.new()
	scheduler.request(script.TIME, "minute")
	scheduler.request(script.TIME, "duplicate minute")
	scheduler.request(script.PLAYER, "inventory")
	var batch: Dictionary = scheduler.consume()
	var empty_batch: Dictionary = scheduler.consume()
	var stats: Dictionary = scheduler.metrics()
	return int(batch["mask"]) == (script.TIME | script.PLAYER) \
		and batch["reasons"] == ["minute", "duplicate minute", "inventory"] \
		and int(empty_batch["mask"]) == 0 \
		and int(stats["flushes"]) == 1 \
		and int(stats["coalesced_requests"]) == 2
