extends "res://scripts/save/save_manager.gd"

var fail_primary_replace := false
var fail_backup_replace := false

func _rename_save_file(from_path: String, to_path: String) -> Error:
	if fail_primary_replace and to_path.ends_with("echo_village_save.json"): return ERR_CANT_CREATE
	if fail_backup_replace and to_path.ends_with(".bak"): return ERR_CANT_CREATE
	return super._rename_save_file(from_path,to_path)

func run_failure_case(root: String, failure: String) -> bool:
	if not configure_test_storage(root.path_join("atomic-save-" + failure)): return false
	GameManager.new_game()
	GameManager.player["coin"] = 91
	if not save_game(): return false
	GameManager.player["coin"] = 123
	if not save_game(): return false
	var primary := _storage_path("echo_village_save.json",SAVE_PATH)
	var backup := primary + ".bak"
	var primary_before := read_limited_text(primary,MAX_SAVE_BYTES)
	var backup_before := read_limited_text(backup,MAX_SAVE_BYTES)
	var blocker := ""
	if failure == "open": blocker = primary + ".tmp"
	if failure == "copy": blocker = backup + ".tmp"
	if not blocker.is_empty() and DirAccess.make_dir_absolute(blocker) != OK: return false
	fail_primary_replace = failure == "rename" or failure == "recovery"
	fail_backup_replace = failure == "backup"
	GameManager.player["coin"] = 777
	var result := false
	if failure == "recovery":
		var corrupt := FileAccess.open(primary,FileAccess.WRITE)
		if corrupt == null: return false
		corrupt.store_string("{ malformed primary")
		corrupt.close()
		primary_before = read_limited_text(primary,MAX_SAVE_BYTES)
		result = load_game() and last_load_recovered and int(GameManager.player["coin"]) == 91
	else:
		var saved := save_game()
		if failure == "backup":
			result = saved and bool(_read_save_candidate(primary).get("ok",false)) and read_limited_text(primary,MAX_SAVE_BYTES) != primary_before
		else:
			result = not saved and read_limited_text(primary,MAX_SAVE_BYTES) == primary_before
	result = result and read_limited_text(backup,MAX_SAVE_BYTES) == backup_before
	if failure == "recovery": result = result and read_limited_text(primary,MAX_SAVE_BYTES) == primary_before
	if not blocker.is_empty(): DirAccess.remove_absolute(blocker)
	fail_primary_replace = false
	fail_backup_replace = false
	# A transient filesystem failure must not poison the next successful save.
	GameManager.player["coin"] = 888
	return result and save_game() and load_game() and int(GameManager.player["coin"]) == 888
