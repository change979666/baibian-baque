extends SceneTree
## P0-3 / P1-4 audit suite: pattern table, wildcard logic, template priority,
## event/gold multiplier stacking, settlement caps.
## NOTE: asserts CURRENT confirmed rules. Do not loosen judgment to pass.

var _next_id: int = 0

func N(suit: int, rank: int) -> Card:
	_next_id += 1
	return Card.new(_next_id, suit, rank)

func W() -> Card:
	_next_id += 1
	return Card.new(_next_id, Card.Suit.NONE, 0, Card.CardType.WILD)

func OPP() -> Card:
	_next_id += 1
	return Card.new(_next_id, Card.Suit.NONE, 0, Card.CardType.OPPORTUNITY)

const S = Card.Suit.SPADE
const H = Card.Suit.HEART
const C = Card.Suit.CLUB
const D = Card.Suit.DIAMOND
const NO_GOLD: Array[int] = [6, 7, 9] # arbitrary gold ranks that tests can avoid/use

var failures: Array[String] = []

func expect(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		print("[PASS] ", name)
	else:
		print("[FAIL] ", name, " ", detail)
		failures.append(name)

func eval_pat(hand: Array[Card], gold: Array[int] = NO_GOLD, events: Dictionary = {}) -> HandEvaluator.HandEvalResult:
	return HandEvaluator.evaluate_hand(hand, gold, events)

func expect_pattern(hand: Array[Card], pat_name: String, mult: int, gold: Array[int] = NO_GOLD) -> void:
	var res = eval_pat(hand, gold)
	expect(res.valid, "valid:" + pat_name, "invalid hand")
	if res.valid:
		expect(res.pattern_name == pat_name and res.base_multiplier == mult,
			"pattern:" + pat_name + " x" + str(mult),
			"got " + res.pattern_name + " x" + str(res.base_multiplier))

func _init() -> void:
	print("====== PATTERN / MULTIPLIER AUDIT ======")

	# ---------- Tier x100 ----------
	var hand: Array[Card] = []
	for i in range(8): hand.append(N(i % 4, 14))
	expect_pattern(hand, PatternDef.DU_YI_WU_ER, 100)

	hand = []
	for i in range(8): hand.append(N(i % 4, 13))
	expect_pattern(hand, PatternDef.JUN_LIN_TIAN_XIA, 100)

	hand = []
	for i in range(8): hand.append(N(i % 4, 10))
	expect_pattern(hand, PatternDef.SHI_QUAN_SHI_MEI, 100)

	hand = []
	for i in range(8): hand.append(N(i % 4, 8))
	expect_pattern(hand, PatternDef.BA_FANG_LAI_CAI, 100)

	# ---------- x50 Ba Fang Lai He: other 8-set ----------
	hand = []
	for i in range(8): hand.append(N(i % 4, 12)) # 8x Q
	expect_pattern(hand, PatternDef.BA_FANG_LAI_HE, 50)

	# ---------- x50 Ba Fang Lai He: 8-run, must beat [4,4] split (x4) ----------
	hand = [N(H,6), N(H,7), N(H,8), N(H,9), N(H,10), N(H,11), N(H,12), N(H,13)]
	expect_pattern(hand, PatternDef.BA_FANG_LAI_HE, 50)

	# ---------- x32 specials ----------
	hand = []
	for i in range(6): hand.append(N(i % 4, 13))
	hand.append(N(S,14)); hand.append(N(H,14))
	expect_pattern(hand, PatternDef.DING_FENG_XIANG_JIAN, 32)

	hand = []
	for i in range(6): hand.append(N(i % 4, 11))
	hand.append(N(S,12)); hand.append(N(H,12))
	expect_pattern(hand, PatternDef.XIN_XIN_XIANG_LIAN, 32)

	hand = []
	for i in range(6): hand.append(N(i % 4, 10))
	hand.append(N(S,9)); hand.append(N(H,9))
	expect_pattern(hand, PatternDef.SHI_NA_JIU_WEN, 32)

	hand = []
	for i in range(6): hand.append(N(i % 4, 6))
	hand.append(N(S,7)); hand.append(N(H,7))
	expect_pattern(hand, PatternDef.LIU_SHI_XING_WANG, 32)

	# ---------- x16 Bi Yi Wei Lin (6+2 adjacent, mixed colors) ----------
	hand = [N(H,6), N(H,7), N(H,8), N(H,9), N(H,10), N(H,11), N(S,12), N(C,12)]
	expect_pattern(hand, PatternDef.BI_YI_WEI_LIN, 16)

	# ---------- x16 Liu Chao Jin Fen (6+2 same color, wilds colorless) ----------
	hand = [N(H,7), N(H,7), N(D,7), N(D,7), W(), W(), N(H,13), N(D,13)]
	expect_pattern(hand, PatternDef.LIU_CHAO_JIN_FEN, 16)

	# ---------- x8 Liu Liu Da Shun (6+2 plain) ----------
	hand = []
	for i in range(6): hand.append(N(i % 4, 9))
	hand.append(N(S,13)); hand.append(N(C,13))
	expect_pattern(hand, PatternDef.LIU_LIU_DA_SHUN, 8)

	# ---------- x8 Yong Heng Xiang Sui (5+3) ----------
	hand = [N(S,6), N(S,7), N(S,8), N(S,9), N(S,10), N(S,13), N(H,13), N(C,13)]
	expect_pattern(hand, PatternDef.YONG_HENG_XIANG_SUI, 8)

	# ---------- x8 Wu Gu Feng Deng (5+3 same color) ----------
	hand = [N(H,6), N(H,7), N(H,8), N(H,9), N(H,10), N(H,14), N(H,14), N(D,14)]
	expect_pattern(hand, PatternDef.WU_GU_FENG_DENG, 8)

	# ---------- x4 Er Long Teng Fei (4+4 adjacent) ----------
	# four 9s + four 10s: adjacent sets; cannot upgrade to [5,3]/[6,2]/[8]
	hand = [N(S,9), N(H,9), N(C,9), N(D,9), N(S,10), N(H,10), N(C,10), N(D,10)]
	expect_pattern(hand, PatternDef.ER_LONG_TENG_FEI, 4)

	# ---------- x4 Si Ji Fa Cai (4+4 same color, not adjacent) ----------
	hand = [N(H,8), N(H,8), N(D,8), N(D,8), N(H,13), N(H,13), N(D,13), N(D,13)]
	expect_pattern(hand, PatternDef.SI_JI_FA_CAI, 4)

	# ---------- x2 Si Ji Ru Chun (4+4 plain) ----------
	hand = [N(S,8), N(H,8), N(C,8), N(D,8), N(S,13), N(H,13), N(C,13), N(D,13)]
	expect_pattern(hand, PatternDef.SI_JI_RU_CHUN, 2)

	# ---------- x1 Ping Hu (3+3+2, pair set, no wild) ----------
	hand = [N(S,11), N(H,11), N(C,11), N(S,9), N(S,8), N(S,7), N(H,6), N(D,6)]
	expect_pattern(hand, PatternDef.PING_HU, 1)

	# ---------- Wildcard rules ----------
	# Ping Hu forbidden with wild
	hand = [N(S,11), N(H,11), W(), N(S,9), N(S,8), N(S,7), N(H,6), N(D,6)]
	var res = eval_pat(hand)
	expect(not (res.valid and res.pattern_name == PatternDef.PING_HU),
		"wild-forbidden-pinghu", "wild must not form Ping Hu")

	# Wild allowed in higher patterns (6+2 with 1 wild)
	hand = [N(S,7), N(H,7), N(C,7), N(D,7), N(S,7), W(), N(C,6), N(D,6)]
	res = eval_pat(hand)
	expect(res.valid and res.base_multiplier >= 8, "wild-in-6+2", "got " + str(res.valid))

	# Pure wild fill: 4x 9 + 4 wilds -> [8] set of 9 -> Ba Fang Lai He x50
	hand = [N(S,9), N(H,9), N(C,9), N(D,9), W(), W(), W(), W()]
	expect_pattern(hand, PatternDef.BA_FANG_LAI_HE, 50)

	# 6x A + 2 wilds -> Du Yi Wu Er x100 (wilds complement special tier)
	hand = [N(S,14), N(H,14), N(C,14), N(D,14), N(S,14), N(H,14), W(), W()]
	expect_pattern(hand, PatternDef.DU_YI_WU_ER, 100)

	# ---------- Invalid hands ----------
	hand = [N(S,6), N(H,7), N(C,9), N(D,10), N(S,11), N(H,12), N(C,13), N(D,14)]
	expect(not eval_pat(hand).valid, "invalid-random-8")

	# 7 cards -> invalid
	hand = [N(S,11), N(H,11), N(C,11), N(S,9), N(S,8), N(S,7), N(H,6)]
	expect(not eval_pat(hand).valid, "invalid-7-cards")

	# Opportunity card excluded -> 7 scoring + 1 opp = invalid (opp blocks hu)
	hand = [N(S,11), N(H,11), N(C,11), N(S,9), N(S,8), N(S,7), N(H,6), OPP()]
	expect(not eval_pat(hand).valid, "opportunity-blocks-hu")

	# ---------- Gold multiplier (P1-4) ----------
	# Ping hu with gold ranks [11, 8, 6]: J-set=3 golds, 8=1, 6-pair=2 -> count 6
	hand = [N(S,11), N(H,11), N(C,11), N(S,9), N(S,8), N(S,7), N(H,6), N(D,6)]
	res = eval_pat(hand, [6, 8, 11])
	expect(res.valid and res.gold_count == 6 and res.gold_multiplier == 6,
		"gold-count-6", "got count=" + str(res.gold_count))

	# Wilds count as gold
	hand = [N(S,7), N(H,7), N(C,7), N(D,7), N(S,7), W(), N(C,6), N(D,6)]
	res = eval_pat(hand, [12, 13, 14])
	expect(res.valid and res.gold_count == 1 and res.gold_multiplier == 1,
		"wild-is-gold", "got count=" + str(res.gold_count))

	# ---------- Event stacking (P1-4): self x3, di_hu x16, hai_di x4, yingqi x2 ----------
	hand = [N(S,11), N(H,11), N(C,11), N(S,9), N(S,8), N(S,7), N(H,6), N(D,6)]
	res = eval_pat(hand, [12, 13, 14], {"self_draw": true})
	expect(res.final_multiplier == 1 * 3 * 2 * 1, "self-draw+yingqi",
		"got " + str(res.final_multiplier)) # 6 (yingqi: no wild)

	res = eval_pat(hand, [12, 13, 14], {"self_draw": true, "di_hu": true})
	expect(res.final_multiplier == 1 * 3 * (16 * 2) * 1, "di-hu-stack",
		"got " + str(res.final_multiplier)) # 96

	res = eval_pat(hand, [12, 13, 14], {"self_draw": true, "di_hu": true, "hai_di": true})
	expect(res.final_multiplier == 1 * 3 * (16 * 4 * 2) * 1, "full-stack",
		"got " + str(res.final_multiplier)) # 384

	# Chi hu (no self draw): no x3, yingqi still applies
	res = eval_pat(hand, [12, 13, 14], {"self_draw": false})
	expect(res.final_multiplier == 1 * 1 * 2 * 1, "chi-hu-no-selfdraw",
		"got " + str(res.final_multiplier)) # 2

	# Hand with wild -> no yingqi
	hand = [N(S,7), N(H,7), N(C,7), N(D,7), N(S,7), W(), N(C,6), N(D,6)]
	res = eval_pat(hand, [12, 13, 14], {"self_draw": true})
	expect(res.event_multiplier == 1, "wild-no-yingqi", "got ev=" + str(res.event_multiplier))

	# ---------- Settlement caps (P1-4) ----------
	var room = GameRules.get_room("beginner") # base 10, max_win 200000
	# calculated = 10 * 100 * 500 = 500,000 > max_win 200,000 -> capped
	var st = Scoring.settle_beans(room, 100, 0, 500, 999999999)
	expect(st["calculated"] == 500000 and st["capped"] == 200000 and st["cap_applied"],
		"cap-max-win", str(st))

	# calculated 500,000 > loser beans 150,000 -> capped to loser beans
	st = Scoring.settle_beans(room, 100, 0, 500, 150000)
	expect(st["calculated"] == 500000 and st["capped"] == 150000 and st["cap_applied"],
		"cap-loser-beans", str(st))

	# Two different multipliers both above cap -> identical payout (difference lost at cap)
	var st_a = Scoring.settle_beans(room, 100, 0, 500, 999999999)
	var st_b = Scoring.settle_beans(room, 100, 0, 5000, 999999999)
	expect(st_a["capped"] == st_b["capped"], "cap-flattens-difference",
		"a=" + str(st_a["capped"]) + " b=" + str(st_b["capped"]))

	# Below cap, multiplier difference preserved
	st_a = Scoring.settle_beans(room, 50, 20, 2, 999999999)
	st_b = Scoring.settle_beans(room, 50, 20, 4, 999999999)
	expect(st_b["capped"] == st_a["capped"] * 2, "below-cap-keeps-difference",
		"a=" + str(st_a["capped"]) + " b=" + str(st_b["capped"]))

	# Loser score can be negative -> diff larger than winner score
	var loser_hand: Array[Card] = [N(S,6), N(H,9), N(C,12)] # all loose: 0 - 27 = -27
	var l_score = Scoring.calculate_loser_score(loser_hand)
	expect(l_score == -27, "loser-negative-score", "got " + str(l_score))

	# ---------- ting_info ----------
	# 6-set + single: virtual wild completes the pair -> ting at least Liu Liu Da Shun x8
	hand = [N(S,11), N(H,11), N(C,11), N(D,11), N(S,11), N(H,11), N(C,6)]
	var ting = HandEvaluator.ting_info(hand, [12, 13, 14])
	expect(int(ting["multiplier"]) >= 8, "ting-info-basic", str(ting))

	print("=======================================")
	if failures.is_empty():
		print("ALL PATTERN AUDIT TESTS PASSED")
	else:
		print("FAILURES: ", failures.size())
		for f in failures: print("  - ", f)
	quit(0 if failures.is_empty() else 1)
