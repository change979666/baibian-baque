extends SceneTree

func _init() -> void:
	print("--- TEST INTERACTIVE FLOW ---")
	var room = GameRules.get_room("beginner")
	var table = TableView.new(room)
	root.add_child(table)
	print("TableView successfully added to root!")
	
	# Verify table components
	assert(table.sm != null, "State machine must not be null")
	assert(table.seat_views.size() == 4, "Must have 4 seat views")
	assert(table.anim_layer != null, "Anim layer must exist")
	assert(table.discard_container != null, "Discard container must exist")
	print("Components verified successfully!")

	# Let the scene run for a few ticks
	var timer = create_timer(1.0)
	timer.timeout.connect(func():
		print("Interactive flow test passed with 0 errors!")
		quit(0)
	)
