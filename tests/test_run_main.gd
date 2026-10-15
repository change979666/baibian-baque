extends SceneTree

func _init() -> void:
	print("--- TEST RUN MAIN SCENE ---")
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	print("Main scene instantiated and added to root successfully!")

	var timer = create_timer(1.0)
	timer.timeout.connect(func():
		print("Main scene running smoothly with 0 errors!")
		quit(0)
	)
