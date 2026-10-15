extends SceneTree

func _init() -> void:
	print("--- CHECK COMPILATION OF ALL SCRIPTS ---")
	var scripts = [
		"res://src/core/card.gd",
		"res://src/core/deck.gd",
		"res://src/core/game_rules.gd",
		"res://src/core/gold.gd",
		"res://src/core/hand_evaluator.gd",
		"res://src/core/patterns.gd",
		"res://src/core/player_state.gd",
		"res://src/core/scoring.gd",
		"res://src/ai/ai_agent.gd",
		"res://src/system/save_manager.gd",
		"res://src/system/sound_manager.gd",
		"res://src/system/game_state_machine.gd",
		"res://src/ui/card_view.gd",
		"res://src/ui/player_seat.gd",
		"res://src/ui/hu_banner.gd",
		"res://src/ui/opportunity_dialog.gd",
		"res://src/ui/bean_refill_dialog.gd",
		"res://src/ui/main_menu.gd",
		"res://src/ui/table_view.gd",
		"res://src/main.gd"
	]

	for s in scripts:
		var res = load(s)
		if res == null:
			printerr("FAILED to load script: " + s)
			quit(1)
			return
		print("Loaded OK: " + s)

	print("--- ALL SCRIPTS COMPILED SUCCESSFULLY! ---")
	quit(0)
