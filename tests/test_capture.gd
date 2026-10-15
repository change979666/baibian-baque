extends SceneTree

func _init() -> void:
	_run()

func _run() -> void:
	var room = GameRules.get_room("beginner")
	var table = GameTable.new(room)
	root.add_child(table)

	# Wait a few frames for rendering
	for i in range(10):
		await process_frame

	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("F:/BaybianBaQue/tests/screenshot_table.png")
		print("SUCCESS: screenshot saved! Size: ", img.get_size())
	else:
		print("FAILED: image was null")
	quit(0)
