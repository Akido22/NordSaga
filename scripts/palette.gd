class_name Pal
## Палитра Pyxel-версии: 16 базовых цветов. В Godot можно больше,
## но интерфейс и заглушки держатся этих.

const BLACK := Color("0b0b12")  # 0  почти чёрный
const NIGHT := Color("1a1c2c")  # 1  ночная синь / контур
const DARK_WOOD := Color("4a2f23")  # 2  тёмное дерево
const PINE := Color("25402a")  # 3  хвоя
const WOOD := Color("8a5432")  # 4  дерево
const STONE := Color("4e5a6a")  # 5  камень
const STEEL := Color("9aa6b2")  # 6  сталь
const LINEN := Color("ece3c9")  # 7  лён / пергамент
const RED := Color("a8322d")  # 8  червлёный
const FIRE := Color("d97a2b")  # 9  огонь
const GOLD := Color("e8c254")  # 10 золото
const MOSS := Color("5f8f3e")  # 11 мох
const FJORD := Color("3d6e9e")  # 12 фьорд
const DUSK := Color("6b5679")  # 13 сумерки
const SKIN := Color("e0a87a")  # 14 кожа
const SNOW := Color("f4f4f4")  # 15 снег

## По номеру, как в Pyxel (для данных из TOML, где цвета заданы числом).
const BY_INDEX: Array[Color] = [
	BLACK, NIGHT, DARK_WOOD, PINE, WOOD, STONE, STEEL, LINEN,
	RED, FIRE, GOLD, MOSS, FJORD, DUSK, SKIN, SNOW,
]
