extends SceneTree

func _init() -> void:
	print("--- TEST 50 ROUNDS ---")
	var room = GameRules.get_room("normal")
	for i in range(50):
		var sm = GameStateMachine.new(room, true)
		sm.setup_game(200000, 200000)
		sm.start_round(i)
		
		var fail_safe = 0
		while sm.state != GameStateMachine.State.GAME_OVER_STATE:
			fail_safe += 1
			if fail_safe % 1000 == 0:
				print("Round ", i, " at turn ", fail_safe, " state: ", sm.state)
			if fail_safe > 10000:
				print("FAILSAFE BREAK!")
				break
				
			if sm.state == GameStateMachine.State.PLAYING:
				sm._process_turn()
			elif sm.state == GameStateMachine.State.AWAITING_AI_ACTION or sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION:
				var player = sm.players[sm.current_seat]
				if player.hand.size() == 7:
					sm.execute_ai_draw_selection()
				else:
					var discard = AIAgent.choose_discard_card(player, sm.gold_mgr.gold_ranks)
					sm._execute_discard(discard)
			elif sm.state == GameStateMachine.State.AWAITING_HUMAN_ACTION:
				# This shouldn't happen in headless unless human bankrupt prompt
				sm._proceed_to_discard()
			else:
				print("UNKNOWN STATE", sm.state)
				break
				
		assert(sm.state == GameStateMachine.State.GAME_OVER_STATE)
	print("--- 50 ROUNDS FINISHED OK ---")
	quit(0)
