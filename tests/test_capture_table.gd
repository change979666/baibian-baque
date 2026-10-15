extends SceneTree

func _init() -> void:
	print("--- TEST CAPTURE TABLE SCREENSHOT ---")
	var room = GameRules.get_room("beginner")
	var table = GameTable.new(room)
	root.add_child(table)

	# Run 60 frames so UI is rendered
	var frames = 0
	var timer = create_timer(0.8)
	timer.timeout.connect(func():
		var img = root.get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("F:/BaybianBaQue/tests/screenshot_table.png")
			print("Screenshot saved successfully to F:/BaybianBaQue/tests/screenshot_table.png")
		quit(0)
	)
