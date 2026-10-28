extends Node
## Шина событий. Системы общаются сигналами, а не прямыми ссылками друг на друга.

signal clock_minute(minute: int)
signal zone_changed(zone: StringName)
signal activity_changed(activity: StringName)
signal power_changed(on: bool)
signal radio_locked(signal_id: StringName)
signal report_sent(index: int)
signal scare_started(id: StringName)
signal scare_finished(id: StringName)
signal blizzard_changed(on: bool)
signal antenna_iced_changed(iced: bool)
signal door_opened
signal ui_requested(id: StringName)
signal player_died(reason: StringName)
signal shift_ended
signal zimnik_reached
signal flare_fired(pos: Vector3)
signal ending_chosen(id: StringName)
signal chimney_iced_changed(iced: bool)
signal fuel_sputter_changed(active: bool)
signal anemo_iced_changed(iced: bool)
signal input_device_changed(is_gamepad: bool)
signal noise_emitted(pos: Vector3, volume: float, type: StringName)
