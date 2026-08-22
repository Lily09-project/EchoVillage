extends Node

const SAVE_PATH := "user://echo_village_save.json"
const PREFERENCES_PATH := "user://echo_village_preferences.json"
const MAX_SAVE_BYTES := 4 * 1024 * 1024
const MAX_PREFERENCES_BYTES := 64 * 1024
const SaveMigrationService = preload("res://scripts/save/save_migration.gd")
var preferences := {"autosave":true,"motion":true,"fullscreen":false,"audio":true,"onboarding_seen":false}
var last_save_kind := ""
var last_load_recovered := false
var last_recovery_reason := ""
var _test_storage_root := ""

func _ready() -> void:
	load_preferences()
	if not GameTime.day_changed.is_connected(_on_day_changed): GameTime.day_changed.connect(_on_day_changed)

func has_save() -> bool:
	var save_path := _storage_path("echo_village_save.json",SAVE_PATH)
	return FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")

func configure_test_storage(root: String) -> bool:
	# Test-only isolation: never redirect a release build. CI may provide an
	# absolute temporary directory; local runs default to a project-local folder
	# so fuzz/save tests cannot overwrite a developer's real user:// save.
	if not OS.is_debug_build(): return false
	var normalized := root.strip_edges()
	if normalized.is_empty(): return false
	var absolute := ""
	if normalized.begins_with("res://"):
		if normalized.length() <= 6: return false
		absolute = ProjectSettings.globalize_path(normalized)
	elif normalized.begins_with("/") or normalized.begins_with("\\\\") or (normalized.length() >= 3 and normalized[1] == ":" and (normalized[2] == "\\" or normalized[2] == "/")):
		absolute = normalized
	else:
		return false
	if DirAccess.make_dir_recursive_absolute(absolute) != OK and not DirAccess.dir_exists_absolute(absolute): return false
	_test_storage_root = absolute.trim_suffix("/").trim_suffix("\\")
	return true

func _storage_path(filename: String, fallback: String) -> String:
	return _test_storage_root.path_join(filename) if not _test_storage_root.is_empty() else fallback

func get_save_recovery_status() -> Dictionary:
	return {"available":has_save(),"using_backup":last_load_recovered,"reason":last_recovery_reason}

func _absolute_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path

func _write_save_atomically(path: String, payload: String) -> bool:
	var absolute_path := _absolute_path(path)
	var temporary_path := absolute_path + ".tmp"
	var backup_path := absolute_path + ".bak"
	var file := FileAccess.open(temporary_path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(payload)
	file.flush()
	file.close()
	if FileAccess.file_exists(absolute_path):
		if FileAccess.file_exists(backup_path): DirAccess.remove_absolute(backup_path)
		if DirAccess.copy_absolute(absolute_path,backup_path) != OK: return false
	if FileAccess.file_exists(absolute_path): DirAccess.remove_absolute(absolute_path)
	if DirAccess.rename_absolute(temporary_path,absolute_path) != OK:
		if FileAccess.file_exists(temporary_path): DirAccess.remove_absolute(temporary_path)
		return false
	return FileAccess.file_exists(absolute_path)

func _read_save_candidate(path: String) -> Dictionary:
	var raw := read_limited_text(path,MAX_SAVE_BYTES)
	if raw.is_empty(): return {"ok":false,"reason":"無法安全讀取此存檔。"}
	var data = JSON.parse_string(raw)
	if not (data is Dictionary): return {"ok":false,"reason":"存檔內容不是有效 JSON。"}
	var migration: Dictionary = SaveMigrationService.migrate(data)
	if not bool(migration.get("ok",false)): return migration
	return {"ok":true,"data":migration["data"]}

func _promote_backup(path: String) -> bool:
	var absolute_path := _absolute_path(path)
	var backup_path := absolute_path + ".bak"
	var raw := read_limited_text(backup_path,MAX_SAVE_BYTES)
	if raw.is_empty(): return false
	# Recovery must never rotate the corrupted primary over the only known-good
	# backup. Write a dedicated temp file and keep .bak intact if promotion fails.
	var recovery_path := absolute_path + ".recovery.tmp"
	var file := FileAccess.open(recovery_path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(raw)
	file.flush()
	file.close()
	if FileAccess.file_exists(absolute_path): DirAccess.remove_absolute(absolute_path)
	if DirAccess.rename_absolute(recovery_path,absolute_path) != OK:
		if FileAccess.file_exists(recovery_path): DirAccess.remove_absolute(recovery_path)
		return false
	return FileAccess.file_exists(absolute_path) and FileAccess.file_exists(backup_path)

func save_game(kind: String = "manual") -> bool:
	var save_path := _storage_path("echo_village_save.json",SAVE_PATH)
	var payload := JSON.stringify({"save_version":2,"time":GameTime.serialize(),"world_state":GameManager.serialize()},"\t")
	if not _write_save_atomically(save_path,payload): return false
	last_save_kind = kind
	last_load_recovered = false
	last_recovery_reason = ""
	GameManager.add_log("自動儲存完成。" if kind == "auto" else "手動儲存完成。")
	EventBus.save_completed.emit(save_path)
	return true

func autosave_game() -> bool:
	if not bool(preferences.get("autosave",true)): return false
	return save_game("auto")

func _on_day_changed(_day: int, _day_of_week: int) -> void:
	autosave_game()

func load_game() -> bool:
	var save_path := _storage_path("echo_village_save.json",SAVE_PATH)
	last_load_recovered = false
	last_recovery_reason = ""
	if not has_save():
		GameManager.add_log("目前還沒有存檔。")
		return false
	var candidate := _read_save_candidate(save_path)
	if not bool(candidate.get("ok",false)):
		var backup_path := _absolute_path(save_path) + ".bak"
		var backup_candidate := _read_save_candidate(backup_path)
		if not bool(backup_candidate.get("ok",false)):
			last_recovery_reason = str(candidate.get("reason","無法安全讀取此存檔。"))
			GameManager.add_log(last_recovery_reason)
			return false
		candidate = backup_candidate
		last_load_recovered = true
		last_recovery_reason = "主要存檔損壞，已使用上一份備份復原。"
		_promote_backup(save_path)
	var migrated: Dictionary = candidate["data"]
	if not GameManager.deserialize(migrated.get("world_state",{})):
		last_recovery_reason = "存檔世界資料無法安全套用。"
		return false
	GameTime.deserialize(migrated.get("time",{}))
	GameManager.add_log("已讀取存檔並還原模擬狀態。")
	if last_load_recovered: GameManager.add_log(last_recovery_reason)
	return true

func load_preferences() -> Dictionary:
	var preferences_path := _storage_path("echo_village_preferences.json",PREFERENCES_PATH)
	if not FileAccess.file_exists(preferences_path): return preferences.duplicate(true)
	var parsed = JSON.parse_string(read_limited_text(preferences_path,MAX_PREFERENCES_BYTES))
	preferences = sanitize_preferences(parsed)
	return preferences.duplicate(true)

func read_limited_text(path: String, max_bytes: int) -> String:
	if max_bytes < 0 or not FileAccess.file_exists(path): return ""
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > max_bytes: return ""
	return file.get_as_text()

func sanitize_preferences(raw: Variant) -> Dictionary:
	var sanitized: Dictionary = preferences.duplicate(true)
	if not (raw is Dictionary): return sanitized
	var parsed: Dictionary = raw
	for key in sanitized:
		if parsed.has(key) and parsed[key] is bool: sanitized[key] = parsed[key]
	return sanitized

func set_preference(key: String, value: bool) -> bool:
	if not preferences.has(key): return false
	preferences[key] = value
	var file := FileAccess.open(_storage_path("echo_village_preferences.json",PREFERENCES_PATH),FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(preferences,"\t"))
	return true

func get_preference(key: String, fallback: bool = false) -> bool:
	return bool(preferences.get(key,fallback))
