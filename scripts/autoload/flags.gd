# res://scripts/autoload/flags.gd
extends Node

## Рубильник механик (Phase 1 de-bloat).
## Механика живёт, только если:
## (а) заставляет игрока выйти наружу;
## (б) меняет то, что он слышит.
## Всё остальное отключается флагом.

## Все приборы, фотолаборатория, шифроблокнот и ремонт щитка включены.
const OFF: Array[StringName] = []

func on(id: StringName) -> bool:
	return id not in OFF
