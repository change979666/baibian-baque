class_name GameRules
extends RefCounted

class RoomConfig:
	var id: String
	var name: String
	var base_score: int
	var min_beans: int
	## 【预留字段 · 当前未使用】房间欢乐豆上限。代码中无任何逻辑读取本字段，
	## 不要用它做任何判断；如需"房间上限"语义请先评审再启用。
	var max_beans: int
	var max_win: int
	var entry_label: String
	var color: Color

	func _init(p_id: String, p_name: String, p_base: int, p_min: int, p_max: int, p_win: int, p_label: String, p_color: Color) -> void:
		id = p_id
		name = p_name
		base_score = p_base
		min_beans = p_min
		max_beans = p_max
		max_win = p_win
		entry_label = p_label
		color = p_color

static var rooms: Dictionary = {
	"beginner": RoomConfig.new("beginner", "新手场", 10, 1000, 200000, 200000, "1千-20万", Color("#3ecf8e")),
	"normal": RoomConfig.new("normal", "普通场", 35, 5000, 100000000, 5000000, "5千-1亿", Color("#8f7ff0")),
	"advanced": RoomConfig.new("advanced", "高级场", 240, 40000, 999999999, 50000000, "4万以上", Color("#f0a04a")),
	"top": RoomConfig.new("top", "顶级场", 600, 150000, 999999999, 999999999, "15万以上", Color("#f06a6a"))
}

const SELF_DRAW_MULT: int = 3
const DI_HU_MULT: int = 16
const HAI_DI_MULT: int = 4
const YING_QI_MULT: int = 2

const HAND_SIZE: int = 7
const SWAP_COUNT: int = 2
const MAX_DECOMPOSITIONS: int = 100

static func get_room(id: String) -> RoomConfig:
	if rooms.has(id):
		return rooms[id]
	return rooms["beginner"]
