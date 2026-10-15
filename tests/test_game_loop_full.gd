extends SceneTree

func _init() -> void:
	print("--- TEST FULL GAME LOOP ---")
	var room = GameRules.get_room("beginner")
	var sm = GameStateMachine.new(room, false)
	sm.setup_game(200000, 200000)

	var turns_counted = 0
	sm.card_drawn.connect(func(seat, card, is_hai_di):
		print("Card drawn by seat %d: %s" % [seat, card.to_display_string()])
	)

	sm.card_discarded.connect(func(seat, card):
		print("Card discarded by seat %d: %s" % [seat, card.to_display_string()])
	)

	sm.ai_turn_ready.connect(func(seat):
		# AI turn ready -> execute discard and advance
		sm.execute_ai_discard()
		sm.advance_to_next_turn()
	)

	sm.human_action_requested.connect(func():
		# Simulate human discarding a card
		var discard = AIAgent.choose_discard_card(sm.players[0], sm.gold_mgr.gold_ranks)
		sm.human_discard_card(discard)
		sm.advance_to_next_turn()
	)

	sm.game_over.connect(func(summary):
		print("Game over reached successfully!")
		print("Human net beans: %d" % summary["human_net_beans"])
		quit(0)
	)

	sm.start_round(12345)
	# Fast-forward swap
	var p0_swap: Array[Card] = [sm.players[0].hand[0], sm.players[0].hand[1]]
	sm.human_confirm_swap(p0_swap)
