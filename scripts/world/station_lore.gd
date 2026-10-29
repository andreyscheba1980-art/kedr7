class_name StationLore
extends Node3D
## Лор станции в мире: книги и бумаги (Books, BookUI), мелкие тайники, подпол Брагина,
## замурованная комната Голубева в корпусе и кабельный тоннель к «Отзвуку».

const FL := MeteoCorpus.FL
const CAB := MeteoCorpus.CAB


func _ready() -> void:
	_place_books()


## Книги, что лежат на виду (остальные — в тайниках).
func _place_books() -> void:
	BookUI.place(self, &"permyakov", Vector3(1.0, 0.76, 3.85), 12.0)            # стол в жилой
	BookUI.place(self, &"gazeta", Vector3(-1.25, 0.47, 5.6), -20.0)             # на кровати
	BookUI.place(self, &"nastavlenie", Vector3(94.3, FL + 0.78, -30.0), 80.0)   # стол с барографом
	BookUI.place(self, &"vahta", Vector3(91.45, FL + 0.78, -24.4), 5.0)         # стол в кабинете наблюдателя
	BookUI.place(self, &"krossvord", Vector3(95.2, CAB + 0.79, -37.95), 30.0)   # стол в кабине башни
