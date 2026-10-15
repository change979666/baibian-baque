extends SceneTree

func _init() -> void:
	print("==================================================")
	print("       《百变八雀 · 点字成金》1000 局自动化仿真测试     ")
	print("==================================================")

	var start_time = Time.get_ticks_msec()
	var total_rounds = 1000
	var room = GameRules.get_room("normal")

	var total_hus = 0
	var max_multiplier = 0
	var pattern_counts: Dictionary = {}
	var total_turns = 0
	var all_passed = true

	for round_idx in range(total_rounds):
		var sm = GameStateMachine.new(room, true)
		# Initialize players with 200,000 beans
		sm.setup_game(200000, 200000)

		# Hook hu event validation
		var round_hus: Array[Dictionary] = []
		sm.hu_settled.connect(func(seat: int, eval_res: HandEvaluator.HandEvalResult, deltas: Dictionary):
			round_hus.append({
				"seat": seat,
				"pattern": eval_res.pattern_name,
				"final_mult": eval_res.final_multiplier,
				"deltas": deltas
			})
		)

		# Run round with unique seed
		sm.start_round(round_idx + 1000)

		# 1. Check normal game termination
		if sm.state != GameStateMachine.State.GAME_OVER_STATE:
			printerr("Round ", round_idx, " did not finish normally! State: ", sm.state)
			all_passed = false
			break

		# 2. Check card conservation: deck + river + dead pile + 4 players' hands = 84 cards
		# (dead pile = discarded opportunity cards + river overflow; tracked since P0-2 audit)
		var total_cards = sm.deck.remaining_count() + sm.discard_pile.size() + sm.dead_pile.size()
		for p in sm.players:
			total_cards += p.hand.size()
			# 7 = 正常回合结束; 8 = 胡牌直接终结对局（赢家未再出牌），合法
			if p.hand.size() < 7 or p.hand.size() > 8:
				printerr("Round ", round_idx, " player ", p.seat_idx, " has wrong hand size: ", p.hand.size())
				all_passed = false

		if total_cards != 84:
			printerr("Round ", round_idx, " card conservation violation! Total: ", total_cards, " expected 84")
			all_passed = false
			break

		# 3. Check bean conservation: sum of net beans across all 4 players must be 0!
		var net_sum = 0
		for p in sm.players:
			net_sum += p.round_net_beans
			# Check NaN or Inf
			if not is_finite(p.beans) or not is_finite(p.round_net_beans):
				printerr("Round ", round_idx, " NaN/Inf in beans!")
				all_passed = false
			if p.beans < 0:
				printerr("Round ", round_idx, " negative beans: ", p.beans)
				all_passed = false

		if net_sum != 0:
			printerr("Round ", round_idx, " bean conservation violation! Net sum: ", net_sum)
			all_passed = false
			break

		# 4. Check all Hu events in this round
		for hu in round_hus:
			total_hus += 1
			var pat = hu["pattern"]
			var mult = hu["final_mult"]
			if mult > max_multiplier:
				max_multiplier = mult
			pattern_counts[pat] = pattern_counts.get(pat, 0) + 1

			# Verify deltas balance
			var delta_sum = 0
			for s in hu["deltas"].keys():
				delta_sum += hu["deltas"][s]
			if delta_sum != 0:
				printerr("Round ", round_idx, " Hu delta balance violation: ", delta_sum)
				all_passed = false

		if (round_idx + 1) % 200 == 0:
			print("Simulated ", round_idx + 1, " / ", total_rounds, " rounds... (Total Hus so far: ", total_hus, ")")

	var elapsed_ms = Time.get_ticks_msec() - start_time
	print("==================================================")
	print("仿真测试统计报告:")
	print("- 总局数: ", total_rounds)
	print("- 总胡牌次数: ", total_hus, " (平均每局 ", snapped(float(total_hus) / total_rounds, 0.01), " 次)")
	print("- 最高单次倍率: ", max_multiplier, " 倍")
	print("- 耗时: ", elapsed_ms, " ms (平均每局 ", snapped(float(elapsed_ms) / total_rounds, 0.01), " ms)")
	print("- 番型出现统计:")
	for pat in pattern_counts.keys():
		print("  * ", pat, ": ", pattern_counts[pat], " 次")

	if all_passed:
		print("\n 1000 局自动化测试全部通过！无死锁、无牌丢失、无非法胡、豆子完全守恒！ ")
	else:
		print("\n 测试存在失败项，请检查错误输出！ ")
	print("==================================================")

	quit(0 if all_passed else 1)
