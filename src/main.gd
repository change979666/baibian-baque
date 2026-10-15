class_name GameRoot
extends Node

var current_view: Node = null

func _ready() -> void:
	if SoundManager.instance == null:
		var snd = SoundManager.new()
		add_child(snd)
	show_lobby()

func show_lobby() -> void:
	if current_view != null:
		current_view.queue_free()

	var menu = MainMenu.new()
	menu.enter_room_requested.connect(_on_enter_room)
	add_child(menu)
	current_view = menu

func _on_enter_room(room: GameRules.RoomConfig) -> void:
	if current_view != null:
		current_view.queue_free()

	var table = GameTable.new(room)
	table.return_to_lobby_requested.connect(show_lobby)
	add_child(table)
	current_view = table
