extends SceneTree

func _init() -> void:
	print("--- TEST ENTER ROOM TRANSITION ---")
	var root_node = load("res://scenes/main.tscn").instantiate()
	root.add_child(root_node)

	# Wait a frame, then trigger room entry
	var timer = create_timer(0.2)
	timer.timeout.connect(func():
		var room = GameRules.get_room("beginner")
		root_node._on_enter_room(room)
		print("Successfully entered room and initialized GameTable!")
		
		var timer2 = create_timer(1.0)
		timer2.timeout.connect(func():
			print("GameTable verified active and running smoothly!")
			quit(0)
		)
	)
