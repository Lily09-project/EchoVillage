extends Node

const DAYS := 90
const MINUTES_PER_DAY := 1440
const MAX_SAVE_BYTES := 2 * 1024 * 1024
const MAX_MEMORY_GROWTH_BYTES := 64 * 1024 * 1024
const MAX_FINAL_SEGMENT_RATIO := 1.5

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	await get_tree().process_frame
	GameTime.set_simulation_paused(true)
	GameTime.reset_clock()
	GameManager.new_game()
	GameManager.trigger_world_event("minor_danger")
	var initial_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var started_us := Time.get_ticks_usec()
	var segment_started_us := started_us
	var checkpoints: Array[Dictionary] = []

	for day_index in DAYS:
		for _minute in MINUTES_PER_DAY:
			GameTime.advance_minute()
		if (day_index + 1) % 30 == 0:
			var now_us := Time.get_ticks_usec()
			var snapshot := GameManager.serialize()
			checkpoints.append({
				"day": day_index + 1,
				"elapsed_ms": float(now_us - segment_started_us) / 1000.0,
				"memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
				"save_bytes": JSON.stringify(snapshot).to_utf8_buffer().size()
			})
			segment_started_us = now_us

	var final_snapshot := GameManager.serialize()
	var final_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var needs_valid := true
	var agents_valid := true
	for npc in GameManager.npcs.values():
		for value in npc.get("needs", {}).values():
			needs_valid = needs_valid and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 100.0
		agents_valid = agents_valid and not str(npc.get("state", "")).is_empty() and not str(npc.get("action", "")).is_empty()
		var position_value: Vector2 = npc.get("position", Vector2.INF)
		agents_valid = agents_valid and is_finite(position_value.x) and is_finite(position_value.y)

	var first_segment_ms := float(checkpoints[0]["elapsed_ms"])
	var final_segment_ms := float(checkpoints[2]["elapsed_ms"])
	var segment_ratio := final_segment_ms / maxf(first_segment_ms, 0.001)
	var save_bytes := JSON.stringify(final_snapshot).to_utf8_buffer().size()
	var checks := {
		"needs_in_range": needs_valid,
		"agents_responsive": agents_valid,
		"event_completed": GameManager.active_event.is_empty(),
		"save_schema_valid": int(final_snapshot.get("save_version", 0)) >= 3 and final_snapshot.has("npcs") and final_snapshot.has("progression"),
		"save_size_bounded": save_bytes <= MAX_SAVE_BYTES,
		"memory_growth_bounded": final_memory - initial_memory <= MAX_MEMORY_GROWTH_BYTES,
		"performance_drift_bounded": segment_ratio <= MAX_FINAL_SEGMENT_RATIO
	}
	var passed := true
	for value in checks.values():
		passed = passed and bool(value)
	var report := {
		"schema_version": "1.0",
		"project": "EchoVillage",
		"simulated_days": DAYS,
		"elapsed_ms": float(Time.get_ticks_usec() - started_us) / 1000.0,
		"initial_memory_bytes": initial_memory,
		"final_memory_bytes": final_memory,
		"memory_growth_bytes": final_memory - initial_memory,
		"final_save_bytes": save_bytes,
		"final_segment_ratio": segment_ratio,
		"limits": {
			"max_save_bytes": MAX_SAVE_BYTES,
			"max_memory_growth_bytes": MAX_MEMORY_GROWTH_BYTES,
			"max_final_segment_ratio": MAX_FINAL_SEGMENT_RATIO
		},
		"checkpoints": checkpoints,
		"checks": checks,
		"passed": passed
	}
	var file := FileAccess.open("res://tests/soak_test_report.json", FileAccess.WRITE)
	if file == null:
		push_error("Unable to write soak_test_report.json")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SOAK_RESULT passed=%s days=%d elapsed_ms=%.3f save_bytes=%d memory_growth_bytes=%d segment_ratio=%.3f" % [str(passed), DAYS, report["elapsed_ms"], save_bytes, report["memory_growth_bytes"], segment_ratio])
	get_tree().quit(0 if passed else 1)
