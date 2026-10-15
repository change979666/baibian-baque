class_name HandEvaluator
extends RefCounted

class HandGroup:
	var kind: String # "set" or "run"
	var size: int
	var rank_idx: int # 0..8 (6..A)
	var suit: int = Card.Suit.NONE
	var wild_used: int = 0

	func _init(p_kind: String, p_size: int, p_rank_idx: int, p_suit: int = Card.Suit.NONE, p_wild: int = 0) -> void:
		kind = p_kind
		size = p_size
		rank_idx = p_rank_idx
		suit = p_suit
		wild_used = p_wild

	func get_rank_range() -> Vector2i:
		if kind == "set":
			return Vector2i(rank_idx, rank_idx)
		else:
			return Vector2i(rank_idx, rank_idx + size - 1)

class HandEvalResult:
	var valid: bool = false
	var pattern_name: String = ""
	var pattern_id: String = ""
	var base_multiplier: int = 0
	var groups: Array[HandGroup] = []
	var gold_count: int = 0
	var gold_multiplier: int = 1
	var wild_count: int = 0
	var self_draw_multiplier: int = 1
	var event_multiplier: int = 1
	var events: Array[String] = []
	var final_multiplier: int = 0
	var all_same_color: bool = false
	var description: String = ""

const ORDERED_TEMPLATES: Array[Array] = [
	[8],
	[6, 2],
	[5, 3],
	[4, 4],
	[3, 3, 2]
]

static func are_adjacent(g1: HandGroup, g2: HandGroup) -> bool:
	var r1 = g1.get_rank_range()
	var r2 = g2.get_rank_range()
	return r1.y + 1 == r2.x or r2.y + 1 == r1.x

static func check_all_same_color(cards: Array[Card]) -> bool:
	var first_color_is_red: Variant = null
	for c in cards:
		if c.is_wild() or c.is_opportunity():
			continue
		var red = c.is_red()
		if first_color_is_red == null:
			first_color_is_red = red
		elif first_color_is_red != red:
			return false
	return first_color_is_red != null

static func to_counts(cards: Array[Card]) -> PackedByteArray:
	var counts = PackedByteArray()
	counts.resize(36)
	counts.fill(0)
	for c in cards:
		if not c.is_wild() and not c.is_opportunity():
			var r_idx = c.rank - 6
			var s_idx = c.suit
			if r_idx >= 0 and r_idx < 9 and s_idx >= 0 and s_idx < 4:
				counts[r_idx * 4 + s_idx] += 1
	return counts

static func decompose_template(real_cards: Array[Card], wilds: int, template: Array) -> Array:
	var counts = to_counts(real_cards)
	var results: Array = []
	var memo: Dictionary = {}
	_search(counts, wilds, template, [], results, memo)
	return results

static func _get_take_combos(caps: Array, target: int, idx: int, current: Array, out_combos: Array) -> void:
	if target == 0:
		var combo = current.duplicate()
		while combo.size() < 4:
			combo.append(0)
		out_combos.append(combo)
		return
	if idx >= 4:
		return
	var max_take = min(caps[idx], target)
	for take in range(max_take + 1):
		current.append(take)
		_get_take_combos(caps, target - take, idx + 1, current, out_combos)
		current.pop_back()

static func _search(counts: PackedByteArray, wilds_left: int, remaining: Array, acc: Array, results: Array, memo: Dictionary) -> void:
	if results.size() >= GameRules.MAX_DECOMPOSITIONS:
		return

	if remaining.is_empty():
		var any_left = false
		for i in range(36):
			if counts[i] > 0:
				any_left = true
				break
		if not any_left and wilds_left == 0:
			results.append(acc.duplicate())
		return

	# Find first non-zero card
	var first = -1
	for i in range(36):
		if counts[i] > 0:
			first = i
			break

	# If no real cards left, fill remaining slots with pure wildcards
	if first == -1:
		var needed = 0
		for sz in remaining:
			needed += sz
		if needed == wilds_left:
			var fill_acc = acc.duplicate()
			for sz in remaining:
				fill_acc.append(HandGroup.new("set", sz, 0, Card.Suit.NONE, sz))
			results.append(fill_acc)
		return

	var rem_sorted = remaining.duplicate()
	rem_sorted.sort()
	var memo_key = str(counts) + "_" + str(wilds_left) + "_" + str(rem_sorted) + "_" + str(acc.size())
	if memo.has(memo_key):
		return
	memo[memo_key] = true

	var r0 = int(first / 4)
	var s0 = first % 4

	var caps = [0, 0, 0, 0]
	var avail = 0
	for s in range(4):
		caps[s] = counts[r0 * 4 + s]
		avail += caps[s]
	caps[s0] -= 1 # first is already accounted for

	var tried_sizes: Dictionary = {}
	for k in remaining:
		if tried_sizes.has(k):
			continue
		tried_sizes[k] = true

		var next_rem = remaining.duplicate()
		next_rem.erase(k)

		# Branch A: Set of size k at rank r0
		var max_real = min(avail, k)
		for j in range(1, max_real + 1):
			var w = k - j
			if w > wilds_left:
				continue
			# Pick j - 1 cards from other caps
			var combos: Array = []
			_get_take_combos(caps, j - 1, 0, [], combos)
			for combo in combos:
				var next_c = counts.duplicate()
				next_c[first] -= 1
				for s in range(4):
					if combo[s] > 0:
						next_c[r0 * 4 + s] -= combo[s]
				acc.append(HandGroup.new("set", k, r0, Card.Suit.NONE, w))
				_search(next_c, wilds_left - w, next_rem, acc, results, memo)
				acc.pop_back()
				if results.size() >= GameRules.MAX_DECOMPOSITIONS:
					return

		# Branch B: Run of size k of suit s0 covering rank r0
		if k in [3, 4, 5, 6, 8]:
			var min_st = max(0, r0 - k + 1)
			var max_st = min(r0, 9 - k)
			for st in range(min_st, max_st + 1):
				var w = 0
				for p in range(st, st + k):
					if counts[p * 4 + s0] == 0:
						w += 1
				if w <= wilds_left:
					var next_c = counts.duplicate()
					for p in range(st, st + k):
						if next_c[p * 4 + s0] > 0:
							next_c[p * 4 + s0] -= 1
					acc.append(HandGroup.new("run", k, st, s0, w))
					_search(next_c, wilds_left - w, next_rem, acc, results, memo)
					acc.pop_back()
					if results.size() >= GameRules.MAX_DECOMPOSITIONS:
						return

static func match_pattern(groups: Array, wild_count: int, all_same_color: bool) -> Dictionary:
	# groups must be sorted by size descending
	var sizes: Array[int] = []
	for g in groups:
		sizes.append(g.size)

	# Tier 1: Special x100
	if sizes == [8] and groups[0].kind == "set":
		var r = groups[0].rank_idx
		if r == 8: # A (14)
			return {"id": "sp100_A", "name": PatternDef.DU_YI_WU_ER, "multiplier": 100, "desc": "八张A"}
		elif r == 7: # K (13)
			return {"id": "sp100_K", "name": PatternDef.JUN_LIN_TIAN_XIA, "multiplier": 100, "desc": "八张K"}
		elif r == 4: # 10 (10)
			return {"id": "sp100_10", "name": PatternDef.SHI_QUAN_SHI_MEI, "multiplier": 100, "desc": "八张10"}
		elif r == 2: # 8 (8)
			return {"id": "sp100_8", "name": PatternDef.BA_FANG_LAI_CAI, "multiplier": 100, "desc": "八张8"}

	# Tier 2: Special x32 (6+2 specific sets)
	if sizes == [6, 2] and groups[0].kind == "set" and groups[1].kind == "set":
		var r0 = groups[0].rank_idx
		var r1 = groups[1].rank_idx
		if r0 == 7 and r1 == 8:
			return {"id": "sp32_K_A", "name": PatternDef.DING_FENG_XIANG_JIAN, "multiplier": 32, "desc": "K六张+A对"}
		elif r0 == 5 and r1 == 6:
			return {"id": "sp32_J_Q", "name": PatternDef.XIN_XIN_XIANG_LIAN, "multiplier": 32, "desc": "J六张+Q对"}
		elif r0 == 4 and r1 == 3:
			return {"id": "sp32_10_9", "name": PatternDef.SHI_NA_JIU_WEN, "multiplier": 32, "desc": "10六张+9对"}
		elif r0 == 0 and r1 == 1:
			return {"id": "sp32_6_7", "name": PatternDef.LIU_SHI_XING_WANG, "multiplier": 32, "desc": "6六张+7对"}

	# Tier 3: Main Patterns
	if sizes == [8]:
		return {"id": "bafanglaihe", "name": PatternDef.BA_FANG_LAI_HE, "multiplier": 50, "desc": "8张组成完整高阶牌型"}

	if sizes == [6, 2]:
		if are_adjacent(groups[0], groups[1]):
			return {"id": "biyiweilin", "name": PatternDef.BI_YI_WEI_LIN, "multiplier": 16, "desc": "6+2 两组点数相邻"}
		if all_same_color:
			return {"id": "liuchaojinfen", "name": PatternDef.LIU_CHAO_JIN_FEN, "multiplier": 16, "desc": "6+2 全红或全黑"}
		return {"id": "liuliudashun", "name": PatternDef.LIU_LIU_DA_SHUN, "multiplier": 8, "desc": "6+2 同花顺或同数组"}

	if sizes == [5, 3]:
		if are_adjacent(groups[0], groups[1]):
			return {"id": "yonghengxiangsui", "name": PatternDef.YONG_HENG_XIANG_SUI, "multiplier": 8, "desc": "5+3 两个组合点数相邻"}
		if all_same_color:
			return {"id": "wugufengdeng", "name": PatternDef.WU_GU_FENG_DENG, "multiplier": 8, "desc": "5+3 全部同颜色"}
		return {"id": "yonghengxiangsui_base", "name": PatternDef.YONG_HENG_XIANG_SUI, "multiplier": 8, "desc": "5+3 基础组合"}

	if sizes == [4, 4]:
		if are_adjacent(groups[0], groups[1]):
			return {"id": "erlongtengfei", "name": PatternDef.ER_LONG_TENG_FEI, "multiplier": 4, "desc": "4+4 两个组合点数相邻"}
		if all_same_color:
			return {"id": "sijifacai", "name": PatternDef.SI_JI_FA_CAI, "multiplier": 4, "desc": "4+4 全部同颜色"}
		return {"id": "sijiruchun", "name": PatternDef.SI_JI_RU_CHUN, "multiplier": 2, "desc": "4+4 同花顺或同数组"}

	if sizes == [3, 3, 2]:
		if groups[2].kind == "set" and wild_count == 0:
			return {"id": "pinghu", "name": PatternDef.PING_HU, "multiplier": 1, "desc": "3+3+2（无癞子平胡）"}

	return {}

static func evaluate_hand(cards: Array[Card], gold_ranks: Array[int], events: Dictionary = {}) -> HandEvalResult:
	var result = HandEvalResult.new()
	var scoring_cards: Array[Card] = []
	var wild_count = 0
	var real_cards: Array[Card] = []

	for c in cards:
		if c.is_opportunity():
			continue
		scoring_cards.append(c)
		if c.is_wild():
			wild_count += 1
		else:
			real_cards.append(c)

	if scoring_cards.size() != 8:
		return result

	var same_color = check_all_same_color(scoring_cards)
	result.wild_count = wild_count
	result.all_same_color = same_color

	var gold_mgr = GoldManager.new(gold_ranks)
	result.gold_count = gold_mgr.count_gold_cards(scoring_cards)
	result.gold_multiplier = gold_mgr.get_gold_multiplier(scoring_cards)

	var best_pattern: Dictionary = {}
	var best_groups: Array = []

	for tpl in ORDERED_TEMPLATES:
		var decomps = decompose_template(real_cards, wild_count, tpl)
		for groups in decomps:
			var sorted_groups = groups.duplicate()
			sorted_groups.sort_custom(func(a, b): return a.size > b.size)
			var pat = match_pattern(sorted_groups, wild_count, same_color)
			if not pat.is_empty():
				if best_pattern.is_empty() or pat["multiplier"] > best_pattern["multiplier"]:
					best_pattern = pat
					best_groups = sorted_groups
		if not best_pattern.is_empty() and best_pattern["multiplier"] >= 100:
			break

	if best_pattern.is_empty():
		return result

	result.valid = true
	result.pattern_name = best_pattern["name"]
	result.pattern_id = best_pattern["id"]
	result.base_multiplier = best_pattern["multiplier"]
	result.description = best_pattern["desc"]
	result.groups.assign(best_groups)

	result.self_draw_multiplier = GameRules.SELF_DRAW_MULT if events.get("self_draw", false) else 1
	var ev_mult = 1
	if events.get("di_hu", false):
		result.events.append("地胡")
		ev_mult *= GameRules.DI_HU_MULT
	if events.get("hai_di", false):
		result.events.append("海底捞月")
		ev_mult *= GameRules.HAI_DI_MULT
	if wild_count == 0:
		result.events.append("硬气")
		ev_mult *= GameRules.YING_QI_MULT

	result.event_multiplier = ev_mult
	result.final_multiplier = result.base_multiplier * result.self_draw_multiplier * result.event_multiplier * result.gold_multiplier

	return result

static func can_hu(cards: Array[Card], gold_ranks: Array[int], events: Dictionary = {}) -> bool:
	return evaluate_hand(cards, gold_ranks, events).valid

static func ting_info(cards: Array[Card], gold_ranks: Array[int]) -> Dictionary:
	var scoring_cards: Array[Card] = []
	var wild_count = 0
	var real_cards: Array[Card] = []

	for c in cards:
		if c.is_opportunity():
			continue
		scoring_cards.append(c)
		if c.is_wild():
			wild_count += 1
		else:
			real_cards.append(c)

	if scoring_cards.size() != 7:
		return {"multiplier": 0, "name": ""}

	# Virtual wildcard added for 8th card
	wild_count += 1
	var same_color = check_all_same_color(scoring_cards)
	var best_multiplier = 0
	var best_name = ""

	for tpl in ORDERED_TEMPLATES:
		var decomps = decompose_template(real_cards, wild_count, tpl)
		for groups in decomps:
			var sorted_groups = groups.duplicate()
			sorted_groups.sort_custom(func(a, b): return a.size > b.size)
			var pat = match_pattern(sorted_groups, wild_count, same_color)
			if not pat.is_empty():
				if pat["multiplier"] > best_multiplier:
					best_multiplier = pat["multiplier"]
					best_name = pat["name"]
		if best_multiplier >= 100:
			break

	return {"multiplier": best_multiplier, "name": best_name}

static func extract_groups(cards: Array[Card]) -> Dictionary:
	var pool: Array[Card] = []
	var wilds: Array[Card] = []
	var used_ids: Dictionary = {}
	var grouped: Array[Card] = []

	for c in cards:
		if c.is_opportunity():
			continue
		if c.is_wild():
			wilds.append(c)
		else:
			pool.append(c)

	# Wildcards automatically grouped
	for w in wilds:
		grouped.append(w)

	var take_set = func(r_idx: int, size: int) -> bool:
		var avail: Array[Card] = []
		for c in pool:
			if used_ids.has(c.id):
				continue
			if c.rank - 6 == r_idx:
				avail.append(c)
		if avail.size() < size:
			return false
		for i in range(size):
			used_ids[avail[i].id] = true
			grouped.append(avail[i])
		return true

	var take_run = func(suit: int, start: int, size: int) -> bool:
		var picked: Array[Card] = []
		for p in range(start, start + size):
			var found: Card = null
			for c in pool:
				if not used_ids.has(c.id) and c.suit == suit and (c.rank - 6) == p:
					found = c
					break
			if found == null:
				return false
			picked.append(found)
		for c in picked:
			used_ids[c.id] = true
			grouped.append(c)
		return true

	for sz in [8, 6, 5, 4, 3]:
		var progress = true
		while progress:
			progress = false
			for r in range(8, -1, -1):
				if take_set.call(r, sz):
					progress = true
			for st in range(9 - sz, -1, -1):
				for s in range(4):
					if take_run.call(s, st, sz):
						progress = true

	for r in range(8, -1, -1):
		take_set.call(r, 2)

	var loose: Array[Card] = []
	for c in cards:
		if not c.is_wild() and not c.is_opportunity() and not used_ids.has(c.id):
			loose.append(c)

	return {"grouped": grouped, "loose": loose}

static func get_chi_combinations(hand: Array[Card], target: Card) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if target == null or target.is_opportunity():
		return results

	# 1. Check Same Rank (Set of 3)
	var same_rank_cards: Array[Card] = []
	var wilds: Array[Card] = []
	for c in hand:
		if c.is_wild():
			wilds.append(c)
		elif c.rank == target.rank:
			same_rank_cards.append(c)

	if same_rank_cards.size() + wilds.size() >= 2:
		var combo_cards: Array[Card] = []
		for c in same_rank_cards:
			if combo_cards.size() < 2:
				combo_cards.append(c)
		for w in wilds:
			if combo_cards.size() < 2:
				combo_cards.append(w)
		results.append({
			"type": "set",
			"name": "同数刻子 (" + target.get_rank_str() + " x3)",
			"cards": combo_cards
		})

	# 2. Check Flush Runs (Same Suit, Sequential)
	if not target.is_wild():
		var r = target.rank
		var s = target.suit
		var same_suit_map: Dictionary = {}
		for c in hand:
			if not c.is_wild() and c.suit == s:
				if not same_suit_map.has(c.rank):
					same_suit_map[c.rank] = []
				same_suit_map[c.rank].append(c)

		var run_configs = [
			[r - 2, r - 1],
			[r - 1, r + 1],
			[r + 1, r + 2]
		]
		for conf in run_configs:
			var r1 = conf[0]
			var r2 = conf[1]
			if r1 >= 6 and r1 <= 14 and r2 >= 6 and r2 <= 14:
				var c1 = same_suit_map.get(r1, [])
				var c2 = same_suit_map.get(r2, [])
				var wild_avail = wilds.duplicate()
				var card1: Card = c1[0] if c1.size() > 0 else (wild_avail.pop_back() if wild_avail.size() > 0 else null)
				var card2: Card = c2[0] if c2.size() > 0 else (wild_avail.pop_back() if wild_avail.size() > 0 else null)
				if card1 != null and card2 != null:
					var all_3 = [target.rank, r1, r2]
					all_3.sort()
					var r_str = Card.get_rank_name(all_3[0]) + "-" + Card.get_rank_name(all_3[1]) + "-" + Card.get_rank_name(all_3[2])
					results.append({
						"type": "run",
						"name": target.get_suit_symbol() + " 同花顺 (" + r_str + ")",
						"cards": [card1, card2]
					})

	return results

static func can_chi(hand: Array[Card], target: Card) -> bool:
	return get_chi_combinations(hand, target).size() > 0
