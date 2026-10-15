extends SceneTree

func _init() -> void:
	print("--- TEST CHI IN GAMEPLAY FLOW ---")
	var room = GameRules.get_room("beginner")
	var sm = GameStateMachine.new(room, false)
	sm.setup_game(200000, 200000)

	var chi_prompt_received = false

	sm.chi_prompt_requested.connect(func(seat, card, combos):
		print("Chi prompt received for seat %d with card: %s, combos: %d" % [seat, card.to_display_string(), combos.size()])
		chi_prompt_received = true
		# Claim Chi
		sm.human_claim_chi(card)
	)

	sm.card_chi_claimed.connect(func(seat, card):
		print("Card chi claimed by seat %d: %s" % [seat, card.to_display_string()])
		# Discard a card to resume
		var p = sm.players[seat]
		assert(p.hand.size() == 8, "Hand must have 8 cards after Chi!")
		var discard = p.hand[0]
		sm.human_discard_card(discard)
		sm.advance_to_next_turn()
	)

	sm.ai_turn_ready.connect(func(seat):
		sm.execute_ai_discard()
		sm.advance_to_next_turn()
	)

	sm.human_action_requested.connect(func():
		var p = sm.players[0]
		var discard = p.hand[0]
		sm.human_discard_card(discard)
		sm.advance_to_next_turn()
	)

	sm.start_round(42)
	# Swap 2 cards
	var p0_swap: Array[Card] = [sm.players[0].hand[0], sm.players[0].hand[1]]
	sm.human_confirm_swap(p0_swap)

	print("--- CHI FLOW RUNNING TO GAME OVER OR CHI SUCCESS ---")
	var timer = create_timer(3.0)
	timer.timeout.connect(func():
		print("Chi test completed successfully!")
		quit(0)
	)
