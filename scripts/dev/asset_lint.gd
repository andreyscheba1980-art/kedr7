extends Node
## Debug-only verification of critical game assets, palettes, inputs, and loc keys.

func _ready() -> void:
	if not OS.is_debug_build():
		return
	await get_tree().process_frame
	var errors := 0

	# 1. InputMap actions
	for action: StringName in [&"interact", &"journal", &"flashlight", &"sprint", &"hold_breath", &"tasks", &"map"]:
		if not InputMap.has_action(action):
			push_error("AssetLint: InputMap lacks action '%s'" % action)
			errors += 1

	# 2. Critical audio paths
	var critical_sfx: Array[String] = [
		"res://assets/audio/ice_hit.ogg",
		"res://assets/audio/door_knock.ogg",
		"res://assets/audio/step_snow_1.ogg",
		"res://assets/audio/clank.ogg",
		"res://assets/audio/echo_loop.ogg",
		"res://assets/sfx/door_handle.ogg",
		"res://assets/sfx/house_creak.ogg",
		"res://assets/sfx/breath_close.ogg",
		"res://assets/sfx/cc0/claw_scrape_1.wav",
	]
	for path in critical_sfx:
		if not ResourceLoader.exists(path):
			push_error("AssetLint: Missing audio file '%s'" % path)
			errors += 1

	# 3. Essential loc keys
	var critical_keys: Array[StringName] = [
		&"sub.finger_numb_fumble",
		&"it.stake",
		&"it.stake_done",
		&"it.booth",
		&"it.booth_done",
		&"thermo.write",
		&"thermo.close_key",
	]
	for k in critical_keys:
		var txt := Loc.t(k)
		if txt.begins_with("[") and txt.ends_with("]"):
			push_error("AssetLint: Missing translation key '%s'" % k)
			errors += 1

	if errors > 0:
		push_warning("AssetLint: Detected %d asset issues at startup" % errors)
	else:
		print("AssetLint: All verified assets OK.")
