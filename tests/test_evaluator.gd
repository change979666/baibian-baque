extends SceneTree

func _init() -> void:
	print("==================================================")
	print("       《百变八雀 · 点字成金》规则与评估器单元测试     ")
	print("==================================================")

	var all_passed = true
	var tests = [
		"test_deck_composition",
		"test_ping_hu_valid",
		"test_ping_hu_with_wildcard_forbidden",
		"test_si_ji_ru_chun",
		"test_er_long_teng_fei",
		"test_ding_feng_xiang_jian",
		"test_du_yi_wu_er_100",
		"test_ba_fang_lai_cai_100",
		"test_wildcard_in_higher_patterns",
		"test_scoring_and_settlement"
	]

	for t in tests:
		var ok = call(t)
		if ok:
			print("[PASS] ", t)
		else:
			print("[FAIL] ", t)
			all_passed = false

	print("==================================================")
	if all_passed:
		print(" ALL UNIT TESTS PASSED SUCCESSFULLY! ")
	else:
		print(" SOME TESTS FAILED! ")
	print("==================================================")

	quit(0 if all_passed else 1)

func test_deck_composition() -> bool:
	var deck = Deck.new()
	if deck.remaining_count() != 84:
		printerr("Deck size error: expected 84, got ", deck.remaining_count())
		return false

	var eights = 0
	var wilds = 0
	var opps = 0
	for c in deck.cards:
		if c.rank == 8:
			eights += 1
		if c.is_wild():
			wilds += 1
		if c.is_opportunity():
			opps += 1

	if eights != 12:
		printerr("Eights count error: expected 12, got ", eights)
		return false
	if wilds != 4:
		printerr("Wilds count error: expected 4, got ", wilds)
		return false
	if opps != 4:
		printerr("Opportunity count error: expected 4, got ", opps)
		return false

	return true

func test_ping_hu_valid() -> bool:
	# J♠ J♥ J♣ + 9♠ 8♠ 7♠ + 6♥ 6♦
	var hand: Array[Card] = [
		Card.new(1, Card.Suit.SPADE, 11),
		Card.new(2, Card.Suit.HEART, 11),
		Card.new(3, Card.Suit.CLUB, 11),
		Card.new(4, Card.Suit.SPADE, 9),
		Card.new(5, Card.Suit.SPADE, 8),
		Card.new(6, Card.Suit.SPADE, 7),
		Card.new(7, Card.Suit.HEART, 6),
		Card.new(8, Card.Suit.DIAMOND, 6)
	]
	var res = HandEvaluator.evaluate_hand(hand, [8, 11, 14])
	if not res.valid:
		printerr("Expected valid Ping Hu, got invalid")
		return false
	if res.pattern_name != PatternDef.PING_HU:
		printerr("Expected Ping Hu, got ", res.pattern_name)
		return false
	if res.base_multiplier != 1:
		printerr("Expected base multiplier 1, got ", res.base_multiplier)
		return false
	return true

func test_ping_hu_with_wildcard_forbidden() -> bool:
	# J♠ J♥ + 🃏 + 9♠ 8♠ 7♠ + 6♥ 6♦ -> Has wildcard, forbidden to win Ping Hu!
	var hand: Array[Card] = [
		Card.new(1, Card.Suit.SPADE, 11),
		Card.new(2, Card.Suit.HEART, 11),
		Card.new(3, Card.Suit.NONE, 0, Card.CardType.WILD),
		Card.new(4, Card.Suit.SPADE, 9),
		Card.new(5, Card.Suit.SPADE, 8),
		Card.new(6, Card.Suit.SPADE, 7),
		Card.new(7, Card.Suit.HEART, 6),
		Card.new(8, Card.Suit.DIAMOND, 6)
	]
	var res = HandEvaluator.evaluate_hand(hand, [8, 11, 14])
	if res.valid and res.pattern_name == PatternDef.PING_HU:
		printerr("Illegal! Wildcard must NOT be allowed to form Ping Hu!")
		return false
	return true

func test_si_ji_ru_chun() -> bool:
	# ♥AKQJ + ♥8♥8♦8♦8 (4+4 base)
	var hand: Array[Card] = [
		Card.new(1, Card.Suit.HEART, 14),
		Card.new(2, Card.Suit.HEART, 13),
		Card.new(3, Card.Suit.HEART, 12),
		Card.new(4, Card.Suit.HEART, 11),
		Card.new(5, Card.Suit.HEART, 8),
		Card.new(6, Card.Suit.HEART, 8),
		Card.new(7, Card.Suit.DIAMOND, 8),
		Card.new(8, Card.Suit.DIAMOND, 8)
	]
	var res = HandEvaluator.evaluate_hand(hand, [6, 7, 8])
	if not res.valid:
		printerr("Expected valid 4+4, got invalid")
		return false
	if res.base_multiplier < 2:
		printerr("Expected multiplier >= 2, got ", res.base_multiplier)
		return false
	return true

func test_er_long_teng_fei() -> bool:
	# A♠A♥A♣A♦ + K♠K♥K♣K♦ (4+4 adjacent ranks)
	var hand: Array[Card] = [
		Card.new(1, Card.Suit.SPADE, 14),
		Card.new(2, Card.Suit.HEART, 14),
		Card.new(3, Card.Suit.CLUB, 14),
		Card.new(4, Card.Suit.DIAMOND, 14),
		Card.new(5, Card.Suit.SPADE, 13),
		Card.new(6, Card.Suit.HEART, 13),
		Card.new(7, Card.Suit.CLUB, 13),
		Card.new(8, Card.Suit.DIAMOND, 13)
	]
	var res = HandEvaluator.evaluate_hand(hand, [6, 7, 8])
	if not res.valid:
		printerr("Expected valid Er Long Teng Fei, got invalid")
		return false
	if res.pattern_name != PatternDef.ER_LONG_TENG_FEI:
		printerr("Expected Er Long Teng Fei, got ", res.pattern_name)
		return false
	if res.base_multiplier != 4:
		printerr("Expected multiplier 4, got ", res.base_multiplier)
		return false
	return true

func test_ding_feng_xiang_jian() -> bool:
	# K*6 + A*2 (6 of K + Pair of A -> x32)
	var hand: Array[Card] = [
		Card.new(1, Card.Suit.SPADE, 13),
		Card.new(2, Card.Suit.HEART, 13),
		Card.new(3, Card.Suit.CLUB, 13),
		Card.new(4, Card.Suit.DIAMOND, 13),
		Card.new(5, Card.Suit.SPADE, 13),
		Card.new(6, Card.Suit.HEART, 13),
		Card.new(7, Card.Suit.SPADE, 14),
		Card.new(8, Card.Suit.HEART, 14)
	]
	var res = HandEvaluator.evaluate_hand(hand, [6, 7, 8])
	if not res.valid:
		printerr("Expected valid Ding Feng Xiang Jian, got invalid")
		return false
	if res.pattern_name != PatternDef.DING_FENG_XIANG_JIAN:
		printerr("Expected Ding Feng Xiang Jian, got ", res.pattern_name)
		return false
	if res.base_multiplier != 32:
		printerr("Expected multiplier 32, got ", res.base_multiplier)
		return false
	return true

func test_du_yi_wu_er_100() -> bool:
	# 8 of A (x100)
	var hand: Array[Card] = []
	for i in range(8):
		hand.append(Card.new(i, i % 4, 14))
	var res = HandEvaluator.evaluate_hand(hand, [6, 7, 8])
	if not res.valid:
		printerr("Expected valid Du Yi Wu Er, got invalid")
		return false
	if res.pattern_name != PatternDef.DU_YI_WU_ER or res.base_multiplier != 100:
		printerr("Expected Du Yi Wu Er x100, got ", res.pattern_name, " x", res.base_multiplier)
		return false
	return true

func test_ba_fang_lai_cai_100() -> bool:
	# 8 of 8 (x100)
	var hand: Array[Card] = []
	for i in range(8):
		hand.append(Card.new(i, i % 4, 8))
	var res = HandEvaluator.evaluate_hand(hand, [6, 7, 8])
	if not res.valid:
		printerr("Expected valid Ba Fang Lai Cai, got invalid")
		return false
	if res.pattern_name != PatternDef.BA_FANG_LAI_CAI or res.base_multiplier != 100:
		printerr("Expected Ba Fang Lai Cai x100, got ", res.pattern_name, " x", res.base_multiplier)
		return false
	return true

func test_wildcard_in_higher_patterns() -> bool:
	# 7*5 + 🃏 + 6*2 -> Wildcard complements the 7s to 6-group, forming 6+2
	var hand: Array[Card] = [
		Card.new(1, Card.Suit.SPADE, 7),
		Card.new(2, Card.Suit.HEART, 7),
		Card.new(3, Card.Suit.CLUB, 7),
		Card.new(4, Card.Suit.DIAMOND, 7),
		Card.new(5, Card.Suit.SPADE, 7),
		Card.new(6, Card.Suit.NONE, 0, Card.CardType.WILD), # wildcard!
		Card.new(7, Card.Suit.CLUB, 6),
		Card.new(8, Card.Suit.DIAMOND, 6)
	]
	var res = HandEvaluator.evaluate_hand(hand, [6, 7, 8])
	if not res.valid:
		printerr("Expected valid 6+2 with wildcard, got invalid")
		return false
	if res.base_multiplier < 8:
		printerr("Expected multiplier >= 8, got ", res.base_multiplier)
		return false
	return true

func test_scoring_and_settlement() -> bool:
	# Hand score calculation test
	var hand: Array[Card] = [
		Card.new(1, Card.Suit.SPADE, 14), # A = 14
		Card.new(2, Card.Suit.HEART, 13), # K = 13
		Card.new(3, Card.Suit.NONE, 0, Card.CardType.WILD) # Wild = 10
	]
	var score = Scoring.calculate_winner_score(hand)
	if score != (14 + 13 + 10):
		printerr("Expected winner score 37, got ", score)
		return false

	var room = GameRules.get_room("beginner")
	var settle = Scoring.settle_beans(room, 50, 20, 2, 10000)
	# base 10 * diff 30 * mult 2 = 600
	if settle["calculated"] != 600 or settle["capped"] != 600:
		printerr("Expected 600, got ", settle)
		return false

	return true
