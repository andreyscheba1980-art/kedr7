class_name ScareContext
extends RefCounted
## Снимок того, где игрок и чем занят. Директор собирает его каждые полсекунды.

var zone: StringName
var activity: StringName
var dark: bool
var flashlight: bool
var tension: float
var minute: int
var night: int
var fatigue: float


func describe() -> String:
	var parts: PackedStringArray = [String(zone), String(activity)]
	if dark:
		parts.append("темно")
	if flashlight:
		parts.append("фонарь")
	return " / ".join(parts)
