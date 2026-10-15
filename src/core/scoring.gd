class_name Scoring
extends RefCounted

static func card_score(c: Card) -> int:
	if c == null:
		return 0
	if c.is_wild():
		return 10
	if c.is_opportunity():
		return 0
	return c.rank

static func calculate_winner_score(hand: Array[Card]) -> int:
	var total = 0
	for c in hand:
		if not c.is_opportunity():
			total += card_score(c)
	return total

static func calculate_loser_score(hand: Array[Card]) -> int:
	var extracted = HandEvaluator.extract_groups(hand)
	var g_sum = 0
	for c in extracted["grouped"]:
		g_sum += card_score(c)
	var l_sum = 0
	for c in extracted["loose"]:
		l_sum += card_score(c)
	return g_sum - l_sum

static func settle_beans(room: GameRules.RoomConfig, w_score: int, l_score: int, final_mult: int, loser_beans: int) -> Dictionary:
	var score_diff = max(0, w_score - l_score)
	var calculated: int = room.base_score * score_diff * final_mult

	if calculated < 0:
		calculated = 0

	var capped: int = calculated
	if room.max_win > 0 and capped > room.max_win:
		capped = room.max_win
	if capped > loser_beans:
		capped = max(0, loser_beans)

	return {
		"calculated": calculated,
		"capped": capped,
		"cap_applied": capped < calculated
	}
