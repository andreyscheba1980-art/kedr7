# res://scripts/autoload/flags.gd
extends Node

## Рубильник механик (Phase 1 de-bloat).
## Механика живёт, только если:
## (а) заставляет игрока выйти наружу;
## (б) меняет то, что он слышит.
## Всё остальное отключается флагом.

const OFF := [
	&"interferometer",
	&"theodolite",
	&"seismograph",
	&"photolab",
	&"board_repair",
	&"cipher",
	&"telemetry",
	&"codebook",
	&"meteor_fax",
]

func on(id: StringName) -> bool:
	return id not in OFF
