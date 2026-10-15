extends SceneTree

func _init() -> void:
	print("--- TEST TABLE REALTIME ---")
	var room = GameRules.get_room("beginner")
	var table = TableView.new(room)
	root.add_child(table)

	# Auto trust mode so it plays automatically
	table.is_trust_mode = true

	# Monitor for 5 seconds of real-time play
	var timer = create_timer(5.0)
	timer.timeout.connect(func():
		print("5 seconds of real-time play completed successfully without crash!")
		quit(0)
	)
