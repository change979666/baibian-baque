extends SceneTree
## LIV-001 termination guard regression tests (final params: K=7 equidistant, W=2048).
## A. Synthetic: STATE_CYCLE_GUARD fires at the 7th equidistant sighting, not before.
## B. Synthetic: STALEMATE_GUARD fires at exactly 2048 no-progress turns, not at 2047.
## C. Synthetic: what counts as stalemate progress (deck/dead/bankrupt only; hu and
##    bean transfers deliberately do NOT reset — real livelocks hu every turn).
## D. Reproduction: gseed=3 round_idx=146 (probe-verified deterministic hu-loop,
##    cycle gap 4) must terminate EARLY via STATE_CYCLE_GUARD; rounds 0..145 must
##    complete with ZERO guard triggers (shadow-verified FP=0 at K=7/W=2048).

var passed := 0
var failed := 0

func expect(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("[PASS] ", name)
	else:
		failed += 1
		printerr("[FAIL] ", name, " ", detail)

func make_playing_sm() -> GameStateMachine:
	var sm = GameStateMachine.new(GameRules.get_room("beginner"), true)
	sm.setup_game(200000, 200000)
	sm.start_round(42) # headless: auto swap + enter_play
	# headless 开局后状态停在 AWAITING_AI_ACTION；_on_turn_completed 的检查点
	# 语义是「完整回合结束、状态回到 PLAYING」，此处直接置位模拟该检查点。
	sm.state = GameStateMachine.State.PLAYING
	return sm

## 模拟「无进展但非精确重复」的检查点：交换牌堆内两张牌（牌堆/死牌堆数量与
## 破产数均不变，不构成 stalemate 进展，但 fingerprint 不重复，避免一级抢先触发）。
func _churn_deck(sm: GameStateMachine, k: int) -> void:
	var n: int = sm.deck.cards.size()
	if n < 3:
		return
	var i: int = (k * 7 + 1) % n
	var j: int = (k * 13 + 5) % n
	if i == j:
		j = (j + 1) % n
	var tmp: Card = sm.deck.cards[i]
	sm.deck.cards[i] = sm.deck.cards[j]
	sm.deck.cards[j] = tmp

func _no_progress_calls(sm: GameStateMachine, times: int, start_k: int = 0) -> void:
	for i in range(times):
		_churn_deck(sm, start_k + i)
		sm._on_turn_completed()

func _init() -> void:
	print("====== LIVELock GUARD AUDIT (K=7, W=2048) ======")
	test_cycle_guard_synthetic()
	test_stalemate_boundary()
	test_progress_semantics()
	test_repro_gseed3_round146()
	print("=======================================")
	print("Passed: ", passed, " / ", passed + failed)
	if failed == 0:
		print("ALL LIVELOCK GUARD TESTS PASSED")
	else:
		print("LIVELOCK GUARD TESTS FAILED: ", failed)
	quit(0 if failed == 0 else 1)

# ---- A: 7th equidistant sighting -> STATE_CYCLE_GUARD ----
func test_cycle_guard_synthetic() -> void:
	var sm = make_playing_sm()
	expect(sm.state == GameStateMachine.State.PLAYING, "cycle-setup-playing", str(sm.state))
	var over: Array = [0]
	var reason_seen: Array = [""]
	sm.game_over.connect(func(s): over[0] += 1)
	sm.termination_guard_triggered.connect(func(r: String, t: int): reason_seen[0] = r)
	for i in range(6): # sightings 1..6 (identical state, gap=1, equidistant)
		sm._on_turn_completed()
		expect(sm.guard_reason == "", "cycle-no-trigger-" + str(i + 1), sm.guard_reason)
	sm._on_turn_completed() # sighting 7 -> repeated full laps -> cycle verdict
	expect(sm.guard_reason == "STATE_CYCLE_GUARD", "cycle-trigger-7th", sm.guard_reason)
	expect(reason_seen[0] == "STATE_CYCLE_GUARD", "cycle-signal")
	expect(over[0] == 1, "cycle-game-over-once", str(over[0]))
	expect(sm.state == GameStateMachine.State.GAME_OVER_STATE, "cycle-ended")

	# 间隔不相等 -> 同一指纹出现 3 次也不触发（等间距是硬性条件）
	var sm2 = make_playing_sm()
	sm2._on_turn_completed()          # t=1: fpA sighting 1
	_churn_deck(sm2, 100)
	sm2._on_turn_completed()          # t=2: fpB sighting 1
	_churn_deck(sm2, 100)             # swap back -> fpA again
	sm2._on_turn_completed()          # t=3: fpA sighting 2 (gap 2)
	sm2._on_turn_completed()          # t=4: fpA sighting 3 (gap 1) -> 2,1 not equidistant
	expect(sm2.guard_reason == "", "cycle-gap-mismatch-no-trigger", sm2.guard_reason)

# ---- B: stalemate boundary at exactly 2048 ----
func test_stalemate_boundary() -> void:
	var sm = make_playing_sm()
	_churn_deck(sm, 0)
	sm._on_turn_completed() # baseline
	_no_progress_calls(sm, 2047, 1) # streak 2047 -> must NOT trigger
	expect(sm.guard_reason == "", "stalemate-2047-no-trigger", sm.guard_reason + " turn=" + str(sm.turn_count))
	_no_progress_calls(sm, 1, 2048) # streak 2048 -> STALEMATE_GUARD
	expect(sm.guard_reason == "STALEMATE_GUARD", "stalemate-2048-trigger", sm.guard_reason)
	expect(sm.state == GameStateMachine.State.GAME_OVER_STATE, "stalemate-ended")

# ---- C: stalemate progress semantics ----
func test_progress_semantics() -> void:
	var sm = make_playing_sm()
	_churn_deck(sm, 0)
	sm._on_turn_completed() # baseline
	_no_progress_calls(sm, 10, 1)
	expect(sm._stale_streak == 10, "streak-10", str(sm._stale_streak))

	# 胡牌不重置 streak（真实 livelock 每回合都胡——若计入进展二级将永远失效）
	sm.players[1].hu_count += 1
	_no_progress_calls(sm, 1, 11)
	expect(sm._stale_streak == 11, "hu-does-not-reset", str(sm._stale_streak))

	# 豆子转移不重置 streak（livelock 中豆子循环转移，同上）
	sm.players[0].beans -= 500
	sm.players[1].beans += 500
	_no_progress_calls(sm, 1, 12)
	expect(sm._stale_streak == 12, "beans-do-not-reset", str(sm._stale_streak))

	# 牌堆减少 = 进展，重置
	sm.deck.cards.pop_back()
	sm._on_turn_completed()
	expect(sm._stale_streak == 0, "deck-resets", str(sm._stale_streak))

	# 死牌堆增长 = 进展，重置
	_no_progress_calls(sm, 5, 13)
	expect(sm._stale_streak == 5, "streak-5", str(sm._stale_streak))
	sm.dead_pile.append(Card.new(9001, Card.Suit.NONE, 0, Card.CardType.NORMAL))
	sm._on_turn_completed()
	expect(sm._stale_streak == 0, "dead-resets", str(sm._stale_streak))

	# 破产 = 进展，重置
	_no_progress_calls(sm, 5, 18)
	sm.players[2].is_bankrupt = true
	sm._on_turn_completed()
	expect(sm._stale_streak == 0, "bankrupt-resets", str(sm._stale_streak))

	# 状态持续变化 -> 一级永不误触发
	expect(sm.guard_reason == "", "cycle-no-false-positive", sm.guard_reason)

# ---- D: real livelock reproduction (probe: gseed=3, round_idx=146, gap 4) ----
func test_repro_gseed3_round146() -> void:
	var room = GameRules.get_room("normal")
	const LIVELOCK_ROUND := 146
	seed(3) # pin global RNG: should_ai_chi uses randf(); whole run deterministic
	var guard_triggers_before := 0
	var hit_reason := ""
	var hit_turns := -1
	var hit_over_count := 0
	var iter_overflow := false

	for round_idx in range(LIVELOCK_ROUND + 1):
		var sm = GameStateMachine.new(room, true)
		sm.setup_game(200000, 200000)
		var over: Array = [0]
		sm.game_over.connect(func(s): over[0] += 1)
		sm.start_round(round_idx * 7 + 1)

		var iterations := 0
		while sm.state != GameStateMachine.State.GAME_OVER_STATE:
			iterations += 1
			if iterations > 200000:
				iter_overflow = true
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
					iter_overflow = true
					break
		if iter_overflow:
			break
		if round_idx == LIVELOCK_ROUND:
			hit_reason = sm.guard_reason
			hit_turns = sm.turn_count
			hit_over_count = over[0]
			# invariants on the guard-terminated round
			var seen: Dictionary = {}
			var total: int = sm.deck.remaining_count() + sm.discard_pile.size() + sm.dead_pile.size()
			var dup := false
			for c in sm.deck.cards + sm.discard_pile + sm.dead_pile:
				if seen.has(c.id): dup = true
				seen[c.id] = true
			var bean_sum := 0
			for p in sm.players:
				total += p.hand.size()
				bean_sum += p.beans
				for c in p.hand:
					if seen.has(c.id): dup = true
					seen[c.id] = true
				expect(p.beans >= 0, "repro-beans-nonneg")
			expect(total == 84 and seen.size() == 84 and not dup, "repro-card-integrity",
				"total=" + str(total) + " uniq=" + str(seen.size()))
			expect(bean_sum == 800000, "repro-bean-conservation", str(bean_sum))
		else:
			if sm.guard_reason != "":
				guard_triggers_before += 1
				printerr("  false-positive guard at round ", round_idx, ": ", sm.guard_reason)

	expect(not iter_overflow, "repro-no-overflow", "guard failed to terminate round 146")
	expect(hit_reason == "STATE_CYCLE_GUARD", "repro-guard-reason", hit_reason)
	expect(hit_turns > 0 and hit_turns < 4000, "repro-early-termination", "turns=" + str(hit_turns))
	expect(hit_over_count == 1, "repro-game-over-once", str(hit_over_count))
	expect(guard_triggers_before == 0, "repro-zero-false-positives",
		str(guard_triggers_before) + " false triggers in 146 normal rounds")
	print("  repro: round 146 ended by ", hit_reason, " at turn ", hit_turns)
