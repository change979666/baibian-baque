extends SceneTree

func _init() -> void:
	print("--- TEST BANKRUPT FLOW START ---")

	# Test 1: Single player bankruptcy deduction & signal
	var room = GameRules.get_room("normal")
	var sm = GameStateMachine.new(room, true)
	sm.setup_game(200000, 100) # AI players only have 100 beans!
	assert(sm.players[1].beans == 100)
	assert(sm.players[1].is_bankrupt == false)

	# Simulate a hu where AI 1 loses more than 100 beans
	var eval_res = HandEvaluator.HandEvalResult.new()
	eval_res.valid = true
	eval_res.pattern_name = "金牌硬气"
	eval_res.pattern_multiplier = 40
	eval_res.final_multiplier = 40

	# Seat 0 wins
	sm.players[0].hand = [
		Card.new(0, Card.Suit.SPADE, 1),
		Card.new(1, Card.Suit.SPADE, 2),
		Card.new(2, Card.Suit.SPADE, 3),
		Card.new(3, Card.Suit.HEART, 5),
		Card.new(4, Card.Suit.HEART, 6),
		Card.new(5, Card.Suit.HEART, 7),
		Card.new(6, Card.Suit.CLUB, 8),
		Card.new(7, Card.Suit.CLUB, 9)
	]
	sm.players[1].hand = [
		Card.new(8, Card.Suit.DIAMOND, 1),
		Card.new(9, Card.Suit.DIAMOND, 3),
		Card.new(10, Card.Suit.DIAMOND, 5),
		Card.new(11, Card.Suit.SPADE, 4),
		Card.new(12, Card.Suit.HEART, 2),
		Card.new(13, Card.Suit.CLUB, 1),
		Card.new(14, Card.Suit.CLUB, 3)
	]

	var bankrupt_seats: Array[int] = []
	sm.player_bankrupt.connect(func(seat): bankrupt_seats.append(seat))

	sm._execute_hu(0, eval_res)

	print("After Hu:")
	print("  Player 0 beans: ", sm.players[0].beans)
	print("  Player 1 beans: ", sm.players[1].beans)
	print("  Player 1 bankrupt: ", sm.players[1].is_bankrupt)
	print("  Bankrupt seats notified: ", bankrupt_seats)

	assert(sm.players[1].beans == 0, "Player 1 beans should be capped at 0")
	assert(sm.players[1].is_bankrupt == true, "Player 1 should be bankrupt")
	assert(bankrupt_seats.has(1), "Signal player_bankrupt(1) should have fired")

	# Test 2: Turn skipping
	# Bankrupt players 1 and 2
	sm.players[2].is_bankrupt = true
	sm.players[3].is_bankrupt = false
	# From seat 0, next active should be seat 3 (skipping 1 and 2)
	var next_s = sm.get_next_active_seat(0)
	print("Next active seat from 0 (with 1,2 bankrupt): ", next_s)
	assert(next_s == 3, "Should skip bankrupt seats 1 and 2 and land on 3")

	# From seat 3, next active should wrap to seat 0
	var next_from_3 = sm.get_next_active_seat(3)
	print("Next active seat from 3: ", next_from_3)
	assert(next_from_3 == 0, "Should wrap around to 0")

	# Test 3: Last active player remaining triggers premature game end
	sm.players[3].is_bankrupt = true
	# Now only seat 0 is active (active count = 1)
	assert(sm.get_active_players_count() == 1, "Only 1 active player should remain")
	sm.advance_to_next_turn()
	assert(sm.state == GameStateMachine.State.GAME_OVER_STATE, "Game should end when <= 1 active player remains")
	print("Single survivor game over check passed!")

	# Test 4: Human player refill and resume
	var sm2 = GameStateMachine.new(room, true)
	sm2.setup_game(100, 200000)
	sm2.players[0].beans = 0
	sm2.players[0].is_bankrupt = true
	assert(sm2.players[0].is_bankrupt == true)

	var resumed_seats: Array[int] = []
	sm2.player_resumed.connect(func(seat): resumed_seats.append(seat))

	sm2.human_refill_and_resume(200000)
	assert(sm2.players[0].beans == 200000)
	assert(sm2.players[0].is_bankrupt == false)
	assert(resumed_seats.has(0))
	print("Human refill and resume check passed!")

	print("--- TEST BANKRUPT FLOW SUCCESS ---")
	quit(0)
