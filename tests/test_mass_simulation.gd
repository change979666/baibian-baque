extends SceneTree
## Mass simulation audit: 5000 rounds, full invariant checks per round.
## Invariants: termination, single game_over, card conservation (incl. dead pile),
## unique card ids, hand size in [7,8] at end, bean conservation / no NaN / no negative,
## every hu re-validated (no illegal hu), multiplier recompute, deltas balance.
## LIV-001: termination guards active. Global RNG pinned for reproducibility.
## Reports: STATE_CYCLE_GUARD / STALEMATE_GUARD / normal GAME_OVER counts,
## deck-empty (流局) / bankruptcy endings, max turns, max hus per round.

const TOTAL_ROUNDS := 5000
const FAIL_SAFE_CAP := 200000  # hard iteration cap per round (must never hit)
const GLOBAL_SEED := 20260915  # pinned: should_ai_chi uses randf()

func _init() -> void:
	print("====== MASS SIMULATION: ", TOTAL_ROUNDS, " ROUNDS (guards ON, gseed=", GLOBAL_SEED, ") ======")
	var start_time: int = Time.get_ticks_msec()
	seed(GLOBAL_SEED)
	var room = GameRules.get_room("normal") # base 35, max_win 5,000,000

	var total_hus := 0
	var max_multiplier := 0
	var pattern_counts: Dictionary = {}
	var cap_hits_max_win := 0
	var zero_delta_hus := 0
	var rounds_deck_empty := 0     # 流局（牌堆摸空）
	var rounds_last_player := 0    # 破产终结（仅剩 1 人）
	var rounds_cycle_guard := 0    # STATE_CYCLE_GUARD
	var rounds_stalemate_guard := 0 # STALEMATE_GUARD
	var rounds_normal_over := 0    # 正常 GAME_OVER（无 guard）
	var max_turns_seen := 0
	var max_hus_in_round := 0
	var all_passed := true

	for round_idx in range(TOTAL_ROUNDS):
		var sm = GameStateMachine.new(room, true)
		sm.setup_game(200000, 200000)

		var round_hus: Array = []
		var over_count: Array = [0]
		var sm_weak: WeakRef = weakref(sm) # weakref: avoid signal-lambda reference cycle
		sm.hu_settled.connect(func(seat: int, eval_res: HandEvaluator.HandEvalResult, deltas: Dictionary):
			var smr: GameStateMachine = sm_weak.get_ref()
			if smr == null:
				return
			var winner: PlayerState = smr.players[seat]
			var recheck = HandEvaluator.evaluate_hand(winner.hand, smr.gold_mgr.gold_ranks, {})
			round_hus.append({
				"seat": seat,
				"pattern": eval_res.pattern_name,
				"final_mult": eval_res.final_multiplier,
				"mult_ok": eval_res.final_multiplier == eval_res.base_multiplier * eval_res.self_draw_multiplier * eval_res.event_multiplier * eval_res.gold_multiplier,
				"revalid": recheck.valid,
				"deltas": deltas
			})
		)
		sm.game_over.connect(func(s): over_count[0] += 1)

		sm.start_round(round_idx * 7 + 1)

		# ---- drive loop ----
		var iterations := 0
		var stuck := false
		while sm.state != GameStateMachine.State.GAME_OVER_STATE:
			iterations += 1
			if iterations > FAIL_SAFE_CAP:
				printerr("Round ", round_idx, " HARD CAP ", FAIL_SAFE_CAP, " iterations, state=", sm.state,
					" turns=", sm.turn_count, " guard=", sm.guard_reason)
				stuck = true
				all_passed = false
				break
			match sm.state:
				GameStateMachine.State.PLAYING:
					sm._process_turn()
				GameStateMachine.State.AWAITING_AI_ACTION, GameStateMachine.State.AWAITING_DRAW_SELECTION:
					var player: PlayerState = sm.players[sm.current_seat]
					if player.hand.size() == 7:
						sm.execute_ai_draw_selection()
					else:
						sm._execute_discard(AIAgent.choose_discard_card(player, sm.gold_mgr.gold_ranks))
				GameStateMachine.State.AWAITING_HUMAN_ACTION:
					sm._proceed_to_discard()
				_:
					printerr("Round ", round_idx, " UNEXPECTED STATE: ", sm.state)
					stuck = true
					all_passed = false
					break
		if stuck:
			break
		if sm.turn_count > max_turns_seen:
			max_turns_seen = sm.turn_count
		if round_hus.size() > max_hus_in_round:
			max_hus_in_round = round_hus.size()

		# ---- invariant 1: game_over emitted exactly once ----
		if over_count[0] != 1:
			printerr("Round ", round_idx, " game_over emitted ", over_count[0], " times!")
			all_passed = false
			break

		# ---- invariant 2: termination reason sane ----
		var active := 0
		for p in sm.players:
			if not p.is_bankrupt: active += 1
		match sm.guard_reason:
			"STATE_CYCLE_GUARD":
				rounds_cycle_guard += 1
			"STALEMATE_GUARD":
				rounds_stalemate_guard += 1
			"":
				rounds_normal_over += 1
				if sm.deck.is_empty():
					rounds_deck_empty += 1
				elif active <= 1:
					rounds_last_player += 1
				else:
					printerr("Round ", round_idx, " ended without valid reason! deck=", sm.deck.remaining_count(), " active=", active)
					all_passed = false
					break
			_:
				printerr("Round ", round_idx, " unknown guard_reason: ", sm.guard_reason)
				all_passed = false
				break

		# ---- invariant 3: card conservation + unique ids + hand sizes ----
		var seen_ids: Dictionary = {}
		var dup_found := false
		var total_cards: int = sm.deck.remaining_count() + sm.discard_pile.size() + sm.dead_pile.size()
		for c in sm.deck.cards + sm.discard_pile + sm.dead_pile:
			if seen_ids.has(c.id): dup_found = true
			seen_ids[c.id] = true
		for p in sm.players:
			total_cards += p.hand.size()
			for c in p.hand:
				if seen_ids.has(c.id): dup_found = true
				seen_ids[c.id] = true
			# 7 = normal end; 8 = hu/guard ended the game mid-turn (legal)
			if p.hand.size() < 7 or p.hand.size() > 8:
				printerr("Round ", round_idx, " hand size ", p.hand.size(), " outside [7,8] at end")
				all_passed = false
		if total_cards != 84 or seen_ids.size() != 84 or dup_found:
			printerr("Round ", round_idx, " card integrity violation: total=", total_cards,
				" unique=", seen_ids.size(), " dup=", dup_found)
			all_passed = false
			break

		# ---- invariant 4: beans ----
		var net_sum := 0
		for p in sm.players:
			net_sum += p.round_net_beans
			if not is_finite(float(p.beans)) or not is_finite(float(p.round_net_beans)):
				printerr("Round ", round_idx, " NaN/Inf beans!")
				all_passed = false
			if p.beans < 0:
				printerr("Round ", round_idx, " negative beans: ", p.beans)
				all_passed = false
		if net_sum != 0:
			printerr("Round ", round_idx, " bean conservation violation: ", net_sum)
			all_passed = false
			break

		# ---- invariant 5: hu legality ----
		for hu in round_hus:
			total_hus += 1
			if not hu["revalid"]:
				printerr("Round ", round_idx, " ILLEGAL HU settled at seat ", hu["seat"], " pattern=", hu["pattern"])
				all_passed = false
			if not hu["mult_ok"]:
				printerr("Round ", round_idx, " multiplier formula mismatch at seat ", hu["seat"])
				all_passed = false
			var dsum := 0
			for k in hu["deltas"].keys():
				dsum += hu["deltas"][k]
				if abs(int(hu["deltas"][k])) == room.max_win and int(k) != int(hu["seat"]):
					cap_hits_max_win += 1
			if dsum != 0:
				printerr("Round ", round_idx, " hu deltas unbalanced: ", dsum)
				all_passed = false
			else:
				var all_zero := true
				for k in hu["deltas"].keys():
					if int(hu["deltas"][k]) != 0:
						all_zero = false
				if all_zero:
					zero_delta_hus += 1 # hu settled but nobody paid
			if hu["final_mult"] > max_multiplier:
				max_multiplier = hu["final_mult"]
			pattern_counts[hu["pattern"]] = pattern_counts.get(hu["pattern"], 0) + 1
		if not all_passed:
			break

		if (round_idx + 1) % 500 == 0:
			print("  ... ", round_idx + 1, " / ", TOTAL_ROUNDS, " rounds, hus so far: ", total_hus,
				" cycle-guards: ", rounds_cycle_guard, " stalemate-guards: ", rounds_stalemate_guard)

	var elapsed: int = Time.get_ticks_msec() - start_time
	print("====== MASS SIMULATION REPORT ======")
	print("rounds: ", TOTAL_ROUNDS)
	print("normal GAME_OVER (no guard): ", rounds_normal_over)
	print("STATE_CYCLE_GUARD triggers: ", rounds_cycle_guard)
	print("STALEMATE_GUARD triggers: ", rounds_stalemate_guard)
	print("end by deck empty (流局): ", rounds_deck_empty, " / end by bankruptcy: ", rounds_last_player)
	print("max turns in a round: ", max_turns_seen)
	print("max hus in a round: ", max_hus_in_round)
	print("total hus: ", total_hus, " (avg ", snapped(float(total_hus) / TOTAL_ROUNDS, 0.01), " /round)")
	print("max multiplier seen: ", max_multiplier)
	print("zero-delta hus (nobody paid): ", zero_delta_hus, " / ", total_hus)
	print("cap hits (single-loser payout == room.max_win): ", cap_hits_max_win)
	print("elapsed: ", elapsed, " ms (avg ", snapped(float(elapsed) / TOTAL_ROUNDS, 0.01), " ms/round)")
	print("pattern stats:")
	for pat in pattern_counts.keys():
		print("  * ", pat, ": ", pattern_counts[pat])
	if all_passed:
		print("ALL ", TOTAL_ROUNDS, " ROUNDS PASSED ALL INVARIANTS")
	else:
		print("MASS SIMULATION FAILED")
	quit(0 if all_passed else 1)
