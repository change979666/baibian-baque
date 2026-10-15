class_name AIAgent
extends RefCounted

static func choose_swap_cards(player: PlayerState, gold_ranks: Array[int]) -> Array[Card]:
	if player.hand.size() <= 2:
		return player.hand.duplicate()

	# Score each card by usefulness; lower score means better candidate to discard/swap away
	var card_scores: Array[Dictionary] = []
	for card in player.hand:
		var score = _evaluate_single_card_value(card, player.hand, gold_ranks)
		card_scores.append({"card": card, "score": score})

	card_scores.sort_custom(func(a, b): return a["score"] < b["score"])

	var chosen: Array[Card] = []
	for item in card_scores:
		if chosen.size() < GameRules.SWAP_COUNT:
			chosen.append(item["card"])

	return chosen

static func choose_discard_card(player: PlayerState, gold_ranks: Array[int]) -> Card:
	if player.hand.is_empty():
		return null

	# 1. If holding an opportunity card, discard it to trigger 4-card pick!
	for card in player.hand:
		if card.is_opportunity():
			return card

	# 2. Evaluate discarding each non-wildcard card
	var candidates: Array[Card] = []
	for card in player.hand:
		if not card.is_wild():
			candidates.append(card)

	# If all cards are wild (extremely rare), must discard one
	if candidates.is_empty():
		return player.hand[0]

	var best_candidate: Card = candidates[0]
	var best_hand_score: float = -999999.0

	for cand in candidates:
		var remaining: Array[Card] = []
		for c in player.hand:
			if c.id != cand.id:
				remaining.append(c)

		# Evaluate strength of remaining 7 cards
		var ting = HandEvaluator.ting_info(remaining, gold_ranks)
		var hand_val: float = float(ting["multiplier"]) * 1000.0

		# Evaluate synergy of remaining cards
		for c in remaining:
			hand_val += _evaluate_single_card_value(c, remaining, gold_ranks)

		# Deduct bonus if we are discarding a gold card
		if GoldManager.new(gold_ranks).is_gold_card(cand):
			hand_val -= 20.0

		if hand_val > best_hand_score:
			best_hand_score = hand_val
			best_candidate = cand

	return best_candidate

static func choose_opportunity_card(options: Array[Card], current_hand: Array[Card], gold_ranks: Array[int]) -> Card:
	if options.is_empty():
		return null

	# If wildcard is an option, always pick it!
	for opt in options:
		if opt.is_wild():
			return opt

	var best_opt: Card = options[0]
	var best_score: float = -999999.0

	for opt in options:
		var test_hand = current_hand.duplicate()
		test_hand.append(opt)

		# 1. Immediate Hu check
		var eval_res = HandEvaluator.evaluate_hand(test_hand, gold_ranks, {"self_draw": true})
		if eval_res.valid:
			return opt

		# 2. Ting score
		var score: float = 0.0
		if GoldManager.new(gold_ranks).is_gold_card(opt):
			score += 50.0

		score += _evaluate_single_card_value(opt, current_hand, gold_ranks)

		if score > best_score:
			best_score = score
			best_opt = opt

	return best_opt

static func _evaluate_single_card_value(card: Card, hand: Array[Card], gold_ranks: Array[int]) -> float:
	if card.is_wild():
		return 5000.0
	if card.is_opportunity():
		return 1000.0

	var val: float = 0.0
	var gold_mgr = GoldManager.new(gold_ranks)
	if gold_mgr.is_gold_card(card):
		val += 30.0

	for other in hand:
		if other.id == card.id or other.is_wild() or other.is_opportunity():
			continue

		# Same rank synergy (Set potential)
		if other.rank == card.rank:
			val += 40.0

		# Same suit run synergy
		if other.suit == card.suit:
			var diff = abs(other.rank - card.rank)
			if diff == 1:
				val += 35.0
			elif diff == 2:
				val += 15.0

	return val

static func should_ai_chi(hand: Array[Card], target: Card, gold_ranks: Array[int]) -> bool:
	if not HandEvaluator.can_chi(hand, target):
		return false
	var test_hand = hand.duplicate()
	test_hand.append(target)
	var eval_res = HandEvaluator.evaluate_hand(test_hand, gold_ranks, {"self_draw": false})
	if eval_res.valid:
		return true

	var current_ting = HandEvaluator.ting_info(hand, gold_ranks)
	for cand in test_hand:
		if cand.is_wild():
			continue
		var rem: Array[Card] = []
		for c in test_hand:
			if c.id != cand.id:
				rem.append(c)
		var new_ting = HandEvaluator.ting_info(rem, gold_ranks)
		if new_ting["multiplier"] > current_ting["multiplier"]:
			return true

	return randf() < 0.35
