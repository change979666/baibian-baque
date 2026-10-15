class_name GameStateMachine
extends RefCounted

signal game_started()
signal gold_revealed(ranks: Array[int])
signal cards_dealt()
signal swap_requested(direction: String)
signal swap_completed(direction: String)
signal turn_started(seat: int, is_human: bool)
signal card_drawn(seat: int, card: Card, is_hai_di: bool)
signal hu_prompt_requested(eval_result: HandEvaluator.HandEvalResult)
signal human_action_requested()
signal hu_settled(seat: int, eval_res: HandEvaluator.HandEvalResult, deltas: Dictionary)
signal card_discarded(seat: int, card: Card)
signal card_discarded_dead(seat: int, card: Card)
signal opportunity_triggered(seat: int, options: Array[Card])
signal draw_selection_requested(seat: int)
signal card_chi_claimed(seat: int, card: Card)
signal ai_turn_ready(seat: int)
signal player_bankrupt(seat: int)
signal human_bankrupt_prompt()
signal player_resumed(seat: int)
signal game_over(summary: Dictionary)
## LIV-001: 双层终止保护触发。reason 为 "STATE_CYCLE_GUARD" 或 "STALEMATE_GUARD"。
signal termination_guard_triggered(reason: String, turn_count: int)
## 完整回合结束检查点广播（观测用：影子实验/遥测；guard 关闭时也会发射）。
signal turn_completed(turn_count: int)

enum State {
	IDLE,
	STARTING,
	GOLD_REVEAL,
	DEALING,
	SWAPPING,
	PLAYING,
	AWAITING_DRAW_SELECTION,
	AWAITING_AI_ACTION,
	AWAITING_HUMAN_ACTION,
	AWAITING_HUMAN_OPPORTUNITY,
	GAME_OVER_STATE
}

var state: State = State.IDLE
var is_headless: bool = false
var room: GameRules.RoomConfig
var deck: Deck
var gold_mgr: GoldManager
var players: Array[PlayerState] = []
var discard_pile: Array[Card] = []
## 死牌堆（数据层唯一事实来源）：被打出的机会卡 + 弃牌河溢出移除的牌。
## 这些牌永久离开本局，不回牌堆。UI 死牌堆视图必须以此为准。
var dead_pile: Array[Card] = []

var current_seat: int = 0
var swap_direction: String = "ccw" # "ccw", "cw", "cross"
var is_first_turn: Array[bool] = [true, true, true, true]
var drawn_card: Card = null
var current_hu_eval: HandEvaluator.HandEvalResult = null

# For opportunity handling
var opp_options: Array[Card] = []

# ---- LIV-001 双层终止保护（termination guard）----
# 职责边界：guard 只观测状态并保证对局终止，不参与任何正常游戏决策，
# 不修改牌型/金牌/癞子/机会牌规则，不修改倍率与结算公式。
# 参数依据见下方实现区注释（1500 局影子实验 + 定向探针实证数据）。
const STALEMATE_TURN_LIMIT := 2048 ## 二级保护：连续无进展完整回合数上限
## 一级保护：同一 fingerprint 连续 CYCLE_SIGHTING_THRESHOLD 次等间距目击才判循环。
const CYCLE_SIGHTING_THRESHOLD := 7

var guard_enabled: bool = true ## 测试可关闭以搜索 livelock 样本；线上恒为 true
var guard_reason: String = ""  ## 诊断原因："" / "STATE_CYCLE_GUARD" / "STALEMATE_GUARD"
var turn_count: int = 0        ## 本局已完成的完整回合数

var _fp_history: Dictionary = {} ## fingerprint 64位哈希 -> [指纹原文, 目击回合序号数组]；长键哈希查找 O(1)，原文仅用于碰撞校验
var _stale_streak: int = 0
var _last_deck_count: int = -1
var _last_dead_count: int = -1
var _last_bankrupt_total: int = 0

func _init(p_room: GameRules.RoomConfig = null, p_headless: bool = false) -> void:
	room = p_room if p_room != null else GameRules.get_room("beginner")
	is_headless = p_headless
	deck = Deck.new()
	gold_mgr = GoldManager.new()

func setup_game(human_beans: int, ai_beans: int = 200000) -> void:
	players.clear()
	discard_pile.clear()
	dead_pile.clear()
	is_first_turn = [true, true, true, true]

	# Seat 0: Human
	players.append(PlayerState.new(0, "玩家 (您)", true, human_beans, 0))
	# Seat 1: AI East
	players.append(PlayerState.new(1, "东海龙王", false, ai_beans, 1))
	# Seat 2: AI North
	players.append(PlayerState.new(2, "诸葛孔明", false, ai_beans, 2))
	# Seat 3: AI West
	players.append(PlayerState.new(3, "财神送宝", false, ai_beans, 3))

	for p in players:
		p.reset_for_round()

func start_round(seed_val: int = -1) -> void:
	state = State.STARTING
	deck.reset(seed_val)
	discard_pile.clear()
	dead_pile.clear()
	is_first_turn = [true, true, true, true]
	_reset_guards()
	for p in players:
		p.reset_for_round()

	emit_signal("game_started")

	# Roll gold ranks
	var rng: RandomNumberGenerator = null
	if seed_val >= 0:
		rng = RandomNumberGenerator.new()
		rng.seed = seed_val
	var ranks = gold_mgr.roll_gold_ranks(rng)
	state = State.GOLD_REVEAL
	emit_signal("gold_revealed", ranks)

	# Deal 7 cards to each of 4 players
	state = State.DEALING
	for i in range(GameRules.HAND_SIZE):
		for p in players:
			p.add_card(deck.draw())

	for p in players:
		p.sort_hand()

	emit_signal("cards_dealt")

	# Swap phase
	state = State.SWAPPING
	var directions = ["ccw", "cw", "cross"]
	if rng:
		swap_direction = directions[rng.randi_range(0, 2)]
	else:
		swap_direction = directions[randi() % 3]

	emit_signal("swap_requested", swap_direction)

	# In headless mode, AI selects swap cards immediately for all
	if is_headless:
		for p in players:
			p.swap_selected = AIAgent.choose_swap_cards(p, gold_mgr.gold_ranks)
		apply_swap()
		enter_play()

func human_confirm_swap(selected_cards: Array[Card]) -> void:
	if state != State.SWAPPING:
		return
	players[0].swap_selected = selected_cards.duplicate()
	for i in range(1, 4):
		players[i].swap_selected = AIAgent.choose_swap_cards(players[i], gold_mgr.gold_ranks)
	apply_swap()
	emit_signal("swap_completed", swap_direction)
	enter_play()

func apply_swap() -> void:
	# Give selected 2 cards to target player
	var given: Array[Array] = [[], [], [], []]
	for i in range(4):
		for c in players[i].swap_selected:
			players[i].remove_card(c)
			given[i].append(c)

	for i in range(4):
		var target_idx = i
		match swap_direction:
			"ccw": target_idx = (i + 1) % 4
			"cw": target_idx = (i + 3) % 4
			"cross": target_idx = (i + 2) % 4
		for c in given[i]:
			players[target_idx].add_card(c)
		players[i].sort_hand()

func get_active_players_count() -> int:
	var count = 0
	for p in players:
		if not p.is_bankrupt:
			count += 1
	return count

func get_next_active_seat(from_seat: int) -> int:
	for step in range(1, 5):
		var s = (from_seat + step) % 4
		if not players[s].is_bankrupt:
			return s
	return -1

func enter_play() -> void:
	state = State.PLAYING
	
	# Flip 1 initial card to the river at the start of the game
	if discard_pile.size() == 0 and not deck.is_empty():
		var initial_card = deck.draw()
		discard_pile.push_front(initial_card)
		emit_signal("card_discarded", -1, initial_card)
	
	current_seat = 0
	if players[0].is_bankrupt:
		current_seat = get_next_active_seat(0)
	if current_seat == -1 or get_active_players_count() <= 1:
		_end_game()
		return
	_process_turn()

func _process_turn() -> void:
	if deck.is_empty() or get_active_players_count() <= 1:
		_end_game()
		return

	if players[current_seat].is_bankrupt:
		var next_s = get_next_active_seat(current_seat)
		if next_s == -1 or get_active_players_count() <= 1:
			_end_game()
			return
		current_seat = next_s

	var player = players[current_seat]
	emit_signal("turn_started", current_seat, player.is_human)

	# River selection is always available if there is at least 1 card
	# The river itself acts as a sliding window of max 4 cards (managed in discard logic)
	var can_pick_river = discard_pile.size() > 0

	if player.is_human and not is_headless and not player.auto_hu:
		if can_pick_river:
			state = State.AWAITING_DRAW_SELECTION
			emit_signal("draw_selection_requested", current_seat)
		else:
			# No river selection, draw from deck directly
			_execute_draw_from_deck()
	else:
		state = State.AWAITING_AI_ACTION
		if is_headless:
			pass # Handled by test loop
		else:
			emit_signal("ai_turn_ready", current_seat)

func execute_ai_draw_selection() -> void:
	var player = players[current_seat]
	var chosen_card = null
	
	# AI can pick from river if there are cards
	if discard_pile.size() > 0:
		for c in discard_pile:
			if not c.is_opportunity():
				var combos = HandEvaluator.get_chi_combinations(player.hand, c)
				if combos.size() > 0 and AIAgent.should_ai_chi(player.hand, c, gold_mgr.gold_ranks):
					chosen_card = c
					break
	
	if chosen_card != null:
		_execute_draw_from_river(chosen_card)
	else:
		_execute_draw_from_deck()

## 人类声明吃牌（从弃牌河拿牌）。card == null 表示放弃吃牌、改为摸牌堆。
## 规则校验（与 AI 同一判定函数 HandEvaluator.get_chi_combinations）：
## 目标牌必须在弃牌河中，且能与手牌组成吃牌组合（同点刻子或同花顺）。
## 校验失败返回 false，状态不变——UI 不得绕过本函数直接拿牌。
func human_claim_chi(card: Card) -> bool:
	if state != State.AWAITING_DRAW_SELECTION:
		return false
	if card == null:
		_execute_draw_from_deck()
		return true
	if not discard_pile.has(card):
		push_warning("human_claim_chi: card is not in the river.")
		return false
	var player: PlayerState = players[current_seat]
	if HandEvaluator.get_chi_combinations(player.hand, card).is_empty():
		return false
	_execute_draw_from_river(card)
	return true

func human_pass_chi() -> void:
	if state != State.AWAITING_DRAW_SELECTION:
		return
	_execute_draw_from_deck()

func _execute_draw_from_river(card: Card) -> void:
	var player = players[current_seat]
	discard_pile.erase(card)
	player.add_card(card)
	drawn_card = card
	
	emit_signal("card_chi_claimed", current_seat, card)
	_check_hu_after_draw(false, false)

func _execute_draw_from_deck() -> void:
	var player = players[current_seat]
	var is_hai_di = (deck.remaining_count() == 1)
	drawn_card = deck.draw()
	player.add_card(drawn_card)

	emit_signal("card_drawn", current_seat, drawn_card, is_hai_di)
	_check_hu_after_draw(true, is_hai_di)

func _check_hu_after_draw(is_self_draw: bool, is_hai_di: bool) -> void:
	var player = players[current_seat]
	var events: Dictionary = {
		"self_draw": is_self_draw,
		"di_hu": is_first_turn[current_seat] if is_self_draw else false,
		"hai_di": is_hai_di
	}
	var eval_res = HandEvaluator.evaluate_hand(player.hand, gold_mgr.gold_ranks, events)
	current_hu_eval = eval_res

	if eval_res.valid:
		if player.is_human:
			if player.auto_hu:
				_execute_hu(current_seat, eval_res)
				_continue_after_hu()
			else:
				if is_headless:
					_execute_hu(current_seat, eval_res)
					_continue_after_hu()
				else:
					state = State.AWAITING_HUMAN_ACTION
					emit_signal("hu_prompt_requested", eval_res)
					return
		else:
			_execute_hu(current_seat, eval_res)
			if is_headless:
				_continue_after_hu()
			else:
				state = State.AWAITING_AI_ACTION
				emit_signal("ai_turn_ready", current_seat)
				return
	else:
		_proceed_to_discard()

func human_declare_hu() -> void:
	if state != State.AWAITING_HUMAN_ACTION or current_hu_eval == null or not current_hu_eval.valid:
		return
	_execute_hu(0, current_hu_eval)
	_continue_after_hu()

func human_pass_hu() -> void:
	if state != State.AWAITING_HUMAN_ACTION:
		return
	_proceed_to_discard()

func _execute_hu(seat: int, eval_res: HandEvaluator.HandEvalResult) -> void:
	var winner = players[seat]
	winner.has_hu = true
	winner.auto_hu = true
	winner.hu_count += 1

	var w_score = Scoring.calculate_winner_score(winner.hand)
	var deltas: Dictionary = {}
	var total_win: int = 0

	for i in range(4):
		if i == seat:
			continue
		var loser = players[i]
		if loser.is_bankrupt:
			continue
		var l_score = Scoring.calculate_loser_score(loser.hand)
		var settle = Scoring.settle_beans(room, w_score, l_score, eval_res.final_multiplier, loser.beans)
		var paid = settle["capped"]
		loser.beans -= paid
		loser.round_net_beans -= paid
		deltas[i] = -paid
		total_win += paid

		if loser.beans <= 0 and not loser.is_bankrupt:
			loser.is_bankrupt = true
			emit_signal("player_bankrupt", i)
			if loser.is_human and not is_headless:
				emit_signal("human_bankrupt_prompt")

	winner.beans += total_win
	winner.round_net_beans += total_win
	deltas[seat] = total_win

	emit_signal("hu_settled", seat, eval_res, deltas)

func _continue_after_hu() -> void:
	if get_active_players_count() <= 1:
		_end_game()
		return
	_proceed_to_discard()

func _proceed_to_discard() -> void:
	if get_active_players_count() <= 1:
		_end_game()
		return
	var player = players[current_seat]
	if player.is_human and not player.auto_hu and not is_headless:
		state = State.AWAITING_HUMAN_ACTION
		emit_signal("human_action_requested")
	else:
		state = State.AWAITING_AI_ACTION
		if is_headless:
			pass # Will be handled by the test loop
		else:
			emit_signal("ai_turn_ready", current_seat)

func execute_ai_discard() -> void:
	if is_headless:
		return
	var player = players[current_seat]
	var discard = AIAgent.choose_discard_card(player, gold_mgr.gold_ranks)
	_execute_discard(discard)

func human_discard_card(card: Card) -> void:
	if state != State.AWAITING_HUMAN_ACTION:
		return
	_execute_discard(card)

func _execute_discard(card: Card) -> void:
	var player = players[current_seat]
	player.remove_card(card)

	if card.is_opportunity():
		player.sort_hand()
		dead_pile.append(card)
		emit_signal("card_discarded_dead", current_seat, card)
		_handle_opportunity()
		return

	discard_pile.push_front(card)
	if discard_pile.size() > 4:
		dead_pile.append(discard_pile.pop_back())
	player.sort_hand()

	emit_signal("card_discarded", current_seat, card)
	_finish_turn()

func _handle_opportunity() -> void:
	if deck.is_empty():
		_finish_turn()
		return
	opp_options = deck.pick_top_cards(4)
	if opp_options.is_empty():
		_finish_turn()
		return
	emit_signal("opportunity_triggered", current_seat, opp_options)

	var player = players[current_seat]
	if player.is_human and not player.auto_hu and not is_headless:
		state = State.AWAITING_HUMAN_OPPORTUNITY
		# Wait for human to pick
	else:
		var picked = AIAgent.choose_opportunity_card(opp_options, player.hand, gold_mgr.gold_ranks)
		_resolve_opportunity(picked)

func human_pick_opportunity(card: Card) -> void:
	if state != State.AWAITING_HUMAN_OPPORTUNITY:
		return
	_resolve_opportunity(card)

func _resolve_opportunity(picked_card: Card) -> void:
	if picked_card == null:
		if not opp_options.is_empty():
			deck.put_back_on_top(opp_options)
			opp_options.clear()
		_finish_turn()
		return

	var player = players[current_seat]
	player.add_card(picked_card)

	# Return remaining options to top of deck in original order
	var returned: Array[Card] = []
	for c in opp_options:
		if c.id != picked_card.id:
			returned.append(c)
	deck.put_back_on_top(returned)
	opp_options.clear()

	# Hand now has 8 cards again. Must discard 1 to return to 7!
	if player.is_human and not player.auto_hu and not is_headless:
		state = State.AWAITING_HUMAN_ACTION
		emit_signal("human_action_requested")
	else:
		if is_headless:
			var discard = AIAgent.choose_discard_card(player, gold_mgr.gold_ranks)
			player.remove_card(discard)

			if discard.is_opportunity():
				player.sort_hand()
				dead_pile.append(discard)
				emit_signal("card_discarded_dead", current_seat, discard)
				_handle_opportunity()
				return

			discard_pile.push_front(discard)
			if discard_pile.size() > 4:
				dead_pile.append(discard_pile.pop_back())
			player.sort_hand()
			emit_signal("card_discarded", current_seat, discard)
			_finish_turn()
		else:
			emit_signal("ai_turn_ready", current_seat)

func _finish_turn() -> void:
	is_first_turn[current_seat] = false
	if is_headless:
		if get_active_players_count() <= 1:
			_end_game()
			return
		var next_s = get_next_active_seat(current_seat)
		if next_s == -1 or get_active_players_count() <= 1:
			_end_game()
			return
		current_seat = next_s
		state = State.PLAYING
		_on_turn_completed()
	else:
		pass

func advance_to_next_turn() -> void:
	# 已终局时直接返回，禁止再次进入 _end_game（否则结算与存档会被重复执行）
	if state == State.GAME_OVER_STATE:
		return
	if deck.is_empty() or get_active_players_count() <= 1:
		_end_game()
		return
	is_first_turn[current_seat] = false
	var next_s = get_next_active_seat(current_seat)
	if next_s == -1 or get_active_players_count() <= 1:
		_end_game()
		return
	current_seat = next_s
	state = State.PLAYING
	_on_turn_completed()
	if state != State.PLAYING:
		return # guard 已终止本局，不再推进
	_process_turn()

func human_refill_and_resume(beans_amount: int) -> void:
	if players.size() > 0:
		players[0].beans += beans_amount
		players[0].is_bankrupt = false
		emit_signal("player_resumed", 0)

func human_forfeit() -> void:
	if players.size() > 0:
		players[0].is_bankrupt = true
		if current_seat == 0:
			advance_to_next_turn()

# ================= LIV-001 双层终止保护 =================
# 一级 STATE_CYCLE_GUARD：完整回合结束后对全局游戏状态生成 canonical
# fingerprint；同一 fingerprint 连续 CYCLE_SIGHTING_THRESHOLD 次等间距目击
# （= 连续多个完整周期逐态一致）即判状态循环，正常终局。
# 参数依据（tests/guard_shadow_experiment.gd，1500 局单遍影子实验，零轨迹分叉）：
#   K=3 误报 41 局、K=6 误报 3 局、K=7 误报 0/1494 正常局；
#   确定性死循环（4/6 样本，周期 4~6）平均第 87 回合被捕获。
# 二级 STALEMATE_GUARD：连续 STALEMATE_TURN_LIMIT 个完整回合牌堆数量、
# 死牌堆数量、破产人数三者全无变化，判僵局正常终局。
# 判据修正依据（tests/probe_stagnation.gd 实证）：
#   - 真实 livelock 几乎每回合都在胡牌且豆子循环转移，「无新胡/无豆子转移」
#     条件在全部 6 个样本上最多积累 2~3 回合，永远触发不了——故剔除；
#   - 正常局的无进展 streak 最长 1660~1729 回合且仍正常结束，
#     W=2048 实测对 1494 个正常局零误报，同时兜住全部随机游走型
#     livelock（约第 2100 回合终止）。
# guard 只观测并保证终止，不参与任何正常游戏决策，
# 不修改牌型/金牌/癞子/机会牌规则，不修改倍率与结算公式。

func _reset_guards() -> void:
	guard_reason = ""
	turn_count = 0
	_fp_history.clear()
	_stale_streak = 0
	_last_deck_count = -1
	_last_dead_count = -1
	_last_bankrupt_total = 0

## 完整回合结束检查点：由 _finish_turn（headless）与 advance_to_next_turn（UI）
## 在座位推进、状态回到 PLAYING 之后调用。
func _on_turn_completed() -> void:
	if state != State.PLAYING:
		return
	turn_count += 1
	emit_signal("turn_completed", turn_count)
	if not guard_enabled:
		return

	# ---- 一级：状态循环检测（连续 K 次目击且间隔全部相等 = 固定周期循环）----
	var fp: String = _state_fingerprint()
	var fp_hash: int = fp.hash()
	var entry: Array = _fp_history.get(fp_hash, [])
	if entry.is_empty() or entry[0] != fp:
		# 首次目击，或 64 位哈希碰撞（概率 ~1e-12 量级）。碰撞时保守覆盖：
		# 后果仅为推迟一次检测，绝不产生误报。
		entry = [fp, []]
	var sightings: Array = entry[1]
	sightings.append(turn_count)
	if sightings.size() > CYCLE_SIGHTING_THRESHOLD:
		sightings.pop_front()
	_fp_history[fp_hash] = entry
	if sightings.size() >= CYCLE_SIGHTING_THRESHOLD:
		var gap: int = int(sightings[1]) - int(sightings[0])
		var equidistant: bool = gap > 0
		for i in range(2, sightings.size()):
			if int(sightings[i]) - int(sightings[i - 1]) != gap:
				equidistant = false
				break
		if equidistant:
			_trigger_guard("STATE_CYCLE_GUARD")
			return

	# ---- 二级：僵局保护（牌堆/死牌堆/破产数连续无任何变化）----
	# 实证：真实 livelock 每回合都在胡且豆子循环转移，胡牌与豆子转移
	# 不构成区分度，故不作为进展判据（见本文件 LIV-001 区块注释）。
	var bankrupt_total := 0
	for p in players:
		if p.is_bankrupt:
			bankrupt_total += 1
	var deck_now: int = deck.remaining_count()
	var dead_now: int = dead_pile.size()
	if _last_deck_count >= 0 \
		and deck_now == _last_deck_count \
		and dead_now == _last_dead_count \
		and bankrupt_total == _last_bankrupt_total:
		_stale_streak += 1
	else:
		_stale_streak = 0
	_last_deck_count = deck_now
	_last_dead_count = dead_now
	_last_bankrupt_total = bankrupt_total

	if _stale_streak >= STALEMATE_TURN_LIMIT:
		_trigger_guard("STALEMATE_GUARD")

func _trigger_guard(reason: String) -> void:
	guard_reason = reason
	push_warning("LIV-001 termination guard: %s at turn %d | %s" % [reason, turn_count, _state_diagnostics()])
	emit_signal("termination_guard_triggered", reason, turn_count)
	_end_game() # 走正常 GAME_OVER / settlement 流程

## Canonical state fingerprint（匹配键）。覆盖：当前玩家、所有活跃玩家手牌、
## 牌堆（有序）、弃牌河（有序）、死牌堆、胡牌状态（has_hu/auto_hu/破产/首回合标记）、
## 当前豆子、金牌、游戏阶段。明确排除：动画、计时器、纯 UI 状态（均不在本数据层）。
## 注意：hu_count（胡牌次数）不进入匹配键——它是单调递增的纯统计量，
## 经 grep 验证不参与任何游戏决策（仅用于结算统计与存档）；若纳入匹配键，
## 任何含胡牌的状态循环都永远无法被检出（探针实证：gseed=1/round=269 与
## gseed=3/round=146 的 livelock 周期内每回合互胡，hu_count 持续增长，
## 含 hu_count 的指纹在 4001 回合内零重复，剔除后周期 38/4 精确命中）。
## hu_count 仍通过 _trigger_guard 的诊断输出记录。
func _state_fingerprint() -> String:
	var parts: PackedStringArray = []
	parts.append("seat=" + str(current_seat))
	parts.append("phase=" + str(state))
	for p in players:
		var h: PackedStringArray = []
		for c in p.hand:
			h.append(str(c.id))
		h.sort() # canonical：与手牌内部排列无关
		parts.append("p%d=%s" % [p.seat_idx, ",".join(h)])
		parts.append("beans%d=%d" % [p.seat_idx, p.beans])
		parts.append("st%d=%d%d%d%d" % [p.seat_idx, int(p.has_hu), int(p.auto_hu), int(p.is_bankrupt), int(is_first_turn[p.seat_idx])])
	var dk: PackedStringArray = []
	for c in deck.cards:
		dk.append(str(c.id))
	parts.append("deck=" + ",".join(dk)) # 有序：摸牌顺序影响后续演化
	var rv: PackedStringArray = []
	for c in discard_pile:
		rv.append(str(c.id))
	parts.append("river=" + ",".join(rv))
	var dd: PackedStringArray = []
	for c in dead_pile:
		dd.append(str(c.id))
	dd.sort() # 死牌堆顺序不影响后续演化，canonical 排序
	parts.append("dead=" + ",".join(dd))
	var g: PackedStringArray = []
	for r in gold_mgr.gold_ranks:
		g.append(str(r))
	parts.append("gold=" + ",".join(g))
	return "|".join(parts)

## 诊断用完整状态描述（含 hu_count），仅用于 guard 触发时的日志。
func _state_diagnostics() -> String:
	var hu: PackedStringArray = []
	for p in players:
		hu.append(str(p.hu_count))
	return "hu_count=[%s] beans=[%d,%d,%d,%d] deck=%d river=%d dead=%d" % [
		",".join(hu), players[0].beans, players[1].beans, players[2].beans, players[3].beans,
		deck.remaining_count(), discard_pile.size(), dead_pile.size()]

func _end_game() -> void:
	# 幂等保护：终局只执行一次。重复触发（如 UI 动画回调与状态推进竞态）
	# 会导致 game_over 信号重复发射、SaveManager 结算被双倍写入。
	if state == State.GAME_OVER_STATE:
		return
	state = State.GAME_OVER_STATE

	var summary = {
		"human_net_beans": players[0].round_net_beans,
		"human_final_beans": players[0].beans,
		"human_hus": players[0].hu_count,
		"players": players,
		"guard_reason": guard_reason, # "" = 正常终局；否则为 LIV-001 诊断原因
		"turn_count": turn_count
	}

	# Persist human player data
	SaveManager.record_round_end(players[0].round_net_beans, players[0].hu_count, "")
	SaveManager.update_beans(players[0].round_net_beans)

	emit_signal("game_over", summary)

func run_headless_simulation() -> Dictionary:
	is_headless = true
	start_round()
	return {
		"game_over": state == State.GAME_OVER_STATE,
		"deck_empty": deck.is_empty(),
		"players": players,
		"discard_count": discard_pile.size()
	}
