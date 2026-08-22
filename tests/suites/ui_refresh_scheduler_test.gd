extends RefCounted

static func run() -> bool:
	var script = load("res://scripts/ui/ui_refresh_scheduler.gd")
	if script == null:
		return _expect(false, "scheduler script loads")
	var scheduler = script.new()
	scheduler.request(script.TIME, "minute")
	scheduler.request(script.TIME, "duplicate minute")
	scheduler.request(script.PLAYER, "inventory")
	var batch: Dictionary = scheduler.consume()
	var empty_batch: Dictionary = scheduler.consume()
	var stats: Dictionary = scheduler.metrics()
	if not _expect(int(batch["mask"]) == (script.TIME | script.PLAYER), "consume merges TIME and PLAYER masks"):
		return false
	if not _expect(batch["reasons"] == ["minute", "duplicate minute", "inventory"], "consume preserves all nonempty reasons"):
		return false
	if not _expect(int(empty_batch["mask"]) == 0, "second consume is empty"):
		return false
	if not _expect(int(stats["flushes"]) == 1, "only nonempty consume increments flushes"):
		return false
	if not _expect(int(stats["coalesced_requests"]) == 2, "metrics count two coalesced requests"):
		return false
	var section_counts: Dictionary = stats["section_counts"]
	if not _expect(int(section_counts.get(script.TIME, 0)) == 1, "merged TIME requests increment TIME section once"):
		return false
	if not _expect(int(section_counts.get(script.PLAYER, 0)) == 1, "PLAYER request increments PLAYER section once"):
		return false

	section_counts[script.TIME] = 99
	var isolated_stats: Dictionary = scheduler.metrics()
	if not _expect(int(isolated_stats["section_counts"].get(script.TIME, 0)) == 1, "metrics section counts are isolated copies"):
		return false

	batch["reasons"].append("caller mutation")
	scheduler.request(script.WORLD, "later world change")
	var later_batch: Dictionary = scheduler.consume()
	var later_stats: Dictionary = scheduler.metrics()
	if not _expect(later_batch["reasons"] == ["later world change"], "returned reasons cannot leak into later batches"):
		return false
	if not _expect(int(later_stats["flushes"]) == 2 and int(later_stats["section_counts"].get(script.WORLD, 0)) == 1, "returned reasons cannot affect scheduler metrics"):
		return false
	return true

static func _expect(condition: bool, diagnostic: String) -> bool:
	if not condition:
		push_error("UiRefreshSchedulerTest: " + diagnostic)
	return condition
