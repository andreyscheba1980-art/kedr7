class_name SafeUI
extends Control
## Сейф с кодовым барабаном: четыре цифры набираешь как в книжке (KMBook). Код — из бумаг станции.

signal closed

static var code := "0000"
static var on_open: Callable

var _book: KMBook
var _hint: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ThermometerUI.backdrop(self)
	ThermometerUI.title_plate(self, Loc.t(&"safe.title"))
	_book = KMBook.new()
	_book.heading = Loc.t(&"safe.heading")
	UiKit.place(self, _book, 0.5, 0.5, 0.5, 0.5, -200, -200, 200, 120)
	_book.setup([{"label": Loc.t(&"safe.row"), "cells": [&"digit", &"digit", &"digit", &"digit"], "unit": ""}])
	var b := UiStyle.stamp_button(Loc.t(&"safe.open").to_upper(), _try)
	UiKit.place(self, b, 0.5, 0.5, 0.5, 0.5, -140, 140, 140, 182)
	var c := UiStyle.text_button(Loc.t(&"thermo.close_key"), func() -> void: closed.emit())
	UiKit.place(self, c, 0.5, 0.5, 0.5, 0.5, -90, 190, 90, 216)
	_hint = ThermometerUI.hint_label(self)
	_hint.text = Loc.t(&"safe.hint")


func _try() -> void:
	var s := "%04d" % int(_book.value(0))
	if s == code:
		closed.emit()
		if on_open.is_valid():
			on_open.call()
	else:
		Game.audio.play_2d("res://assets/sfx/door_handle.ogg", -6.0)
		_hint.text = Loc.t(&"safe.wrong")


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		return
	if event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_ENTER or (event as InputEventKey).keycode == KEY_KP_ENTER):
		_try()
		return
	_book.handle_key(event)
