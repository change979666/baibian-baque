extends SceneTree
## Rule-flow audit: chi validation (P0-1), swap (P1-1), opportunity flow/chain (P1-6),
## bankruptcy & multi-hu blood-flow & end-game idempotence (P1-5), dead pile (P0-2).

var failures: Array[String] = []
var _next_id: int = 1000

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

func expect(cond: bool, name: String, detail: String = "") -> void:
	if cond:
		print("[PASS] ", name)
	else:
		print("[FAIL] ", name, " ", detail)
		failures.append(name)

func total_tracked_cards(sm: GameStateMachine) -> int:
	var n: int = sm.deck.remaining_count() + sm.discard_pile.size() + sm.dead_pile.size()
	for p in sm.players:
		n += p.hand.size()
	return n

# Build a non-headless SM paused at AWAITING_DRAW_SELECTION for the human.
func make_sm_at_draw_selection(seed: int = 42) -> GameStateMachine:
	var sm = GameStateMachine.new(GameRules.get_room("beginner"), false)
	sm.setup_game(200000, 200000)
	sm.start_round(seed)
	var picks: Array[Card] = [sm.players[0].hand[0], sm.players[0].hand[1]]
	sm.human_confirm_swap(picks)
	return sm

func _init() -> void:
	print("====== RULE-FLOW AUDIT ======")
	test_chi_combinations()
	test_human_chi_validation()
	test_swap_directions_and_conservation()
	test_choose_swap_cards_never_dumps_wild()
	test_opportunity_deck_order()
	test_opportunity_flow_and_chain()
	test_opportunity_blocks_hu_count()
	test_settlement_bankruptcy()
	test_multi_hu_blood_flow()
	test_end_game_idempotent()
	test_dead_pile_tracking()

	print("=======================================")
	if failures.is_empty():
		print("ALL RULE-FLOW AUDIT TESTS PASSED")
	else:
		print("FAILURES: ", failures.size())
		for f in failures: print("  - ", f)
	quit(0 if failures.is_empty() else 1)

# ---------------- chi ----------------
func test_chi_combinations() -> void:
	var hand: Array[Card] = [N(S,9), N(H,9), N(C,7), N(D,11), N(S,13), N(H,6), N(C,14)]
	# set chi: target 9, hand has two 9s
	var combos = HandEvaluator.get_chi_combinations(hand, N(D,9))
	expect(combos.size() >= 1 and combos[0]["type"] == "set", "chi-set", str(combos.size()))
	# run chi: target 8 spade... hand has 9S; need 7S or 10S -> no
	combos = HandEvaluator.get_chi_combinations(hand, N(S,8))
	expect(combos.is_empty(), "chi-run-missing", str(combos.size()))
	# run chi with wild fill: hand 9S + wild can chi 8S (7S? no -> 8 as low: 8,9,10 needs 10S; 8 high: 6S,7S)
	var hand2: Array[Card] = [N(S,9), N(S,10), N(C,7), N(D,11), N(S,13), N(H,6), N(C,14)]
	combos = HandEvaluator.get_chi_combinations(hand2, N(S,8))
	expect(combos.size() >= 1 and combos[0]["type"] == "run", "chi-run", str(combos.size()))
	# wild-assisted chi
	var hand3: Array[Card] = [W(), N(S,9), N(C,7), N(D,11), N(S,13), N(H,6), N(C,14)]
	combos = HandEvaluator.get_chi_combinations(hand3, N(S,10))
	expect(combos.size() >= 1, "chi-wild-assist", str(combos.size()))
	# opportunity target can never be chi'd
	combos = HandEvaluator.get_chi_combinations(hand3, OPP())
	expect(combos.is_empty(), "chi-opp-target", str(combos.size()))

func test_human_chi_validation() -> void:
	var sm = make_sm_at_draw_selection(42)
	expect(sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION,
		"reach-draw-selection", "state=" + str(sm.state))
	var player: PlayerState = sm.players[0]
	var hand_before: int = player.hand.size()

	# Find a river card that CANNOT be chi'd -> must be rejected
	var illegal: Card = null
	var legal: Card = null
	for c in sm.discard_pile:
		if HandEvaluator.can_chi(player.hand, c):
			if legal == null: legal = c
		else:
			if illegal == null: illegal = c

	if illegal != null:
		var ok = sm.human_claim_chi(illegal)
		expect(not ok, "chi-reject-illegal", "illegal chi accepted!")
		expect(sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION
			and player.hand.size() == hand_before,
			"chi-reject-keeps-state")
	else:
		print("[SKIP] chi-reject-illegal (all river cards chi-able with this seed)")

	# Card not in river -> rejected
	var ghost: Card = N(S, 6)
	expect(not sm.human_claim_chi(ghost), "chi-reject-ghost-card")

	if legal != null:
		var river_before: int = sm.discard_pile.size()
		var ok = sm.human_claim_chi(legal)
		expect(ok and player.hand.size() == hand_before + 1
			and sm.discard_pile.size() == river_before - 1,
			"chi-accept-legal", "ok=" + str(ok))
	else:
		# No chi-able card: null means draw from deck
		var ok = sm.human_claim_chi(null)
		expect(ok and player.hand.size() == hand_before + 1, "chi-pass-draws-deck", "ok=" + str(ok))

	expect(total_tracked_cards(sm) == 84, "chi-card-conservation", "total=" + str(total_tracked_cards(sm)))

# ---------------- swap ----------------
func test_swap_directions_and_conservation() -> void:
	for dir in ["ccw", "cw", "cross"]:
		var sm = GameStateMachine.new(GameRules.get_room("beginner"), true)
		sm.setup_game(200000, 200000)
		sm.deck.reset(7)
		for p in sm.players:
			p.hand.clear()
		# Give each player 7 identifiable cards
		for i in range(4):
			for k in range(7):
				sm.players[i].hand.append(N(k % 4, 6 + k))
		var marks: Array = []
		for i in range(4):
			var give: Array[Card] = [sm.players[i].hand[0], sm.players[i].hand[1]]
			sm.players[i].swap_selected = give
			marks.append([give[0].id, give[1].id])
		sm.swap_direction = dir
		sm.apply_swap()
		var target_of = func(i: int) -> int:
			match dir:
				"ccw": return (i + 1) % 4
				"cw": return (i + 3) % 4
				_: return (i + 2) % 4
			return -1
		var ok := true
		for i in range(4):
			var t: int = target_of.call(i)
			var ids: Array = []
			for c in sm.players[t].hand: ids.append(c.id)
			if not (ids.has(marks[i][0]) and ids.has(marks[i][1])):
				ok = false
			if sm.players[i].hand.size() != 7:
				ok = false
		expect(ok, "swap-direction-" + dir)

func test_choose_swap_cards_never_dumps_wild() -> void:
	var p = PlayerState.new(0, "t", true, 1000, 0)
	p.hand.append(W()); p.hand.append(W())
	p.hand.append(N(S,9)); p.hand.append(N(H,9)); p.hand.append(N(C,9)); p.hand.append(N(D,9))
	p.hand.append(N(S,13))
	# 4x 9-set + K synergy vs 2 wilds: lowest value cards should be dumped, wilds kept
	var picks = AIAgent.choose_swap_cards(p, [12, 13, 14])
	expect(picks.size() == 2, "swap-picks-2", str(picks.size()))
	var has_wild := false
	for c in picks:
		if c.is_wild(): has_wild = true
	expect(not has_wild, "swap-keeps-wilds")

# ---------------- opportunity ----------------
func test_opportunity_deck_order() -> void:
	var deck = Deck.new(99)
	var top4 = deck.peek(4)
	var picked = deck.pick_top_cards(4)
	expect(picked.size() == 4, "opp-pick-4")
	# Return 3 (drop index 1) in original order
	var returned: Array[Card] = [picked[0], picked[2], picked[3]]
	deck.put_back_on_top(returned)
	var after = deck.peek(3)
	expect(after[0].id == picked[0].id and after[1].id == picked[2].id and after[2].id == picked[3].id,
		"opp-order-preserved",
		"after=" + str([after[0].id, after[1].id, after[2].id]) + " want=" + str([picked[0].id, picked[2].id, picked[3].id]))

func test_opportunity_flow_and_chain() -> void:
	# Craft: human (headless) holds 8 cards incl 2 opportunity cards.
	# Real game discards from 8 -> 7. AI always discards opportunity first,
	# so a 2-opportunity chain must resolve; final hand 7, both opps in dead pile.
	# Deck is shrunk by the crafted card count to keep conservation accounting exact.
	var sm = GameStateMachine.new(GameRules.get_room("beginner"), true)
	sm.setup_game(200000, 200000)
	sm.deck.reset(5)
	var player: PlayerState = sm.players[0]
	player.hand.clear()
	var crafted: Array[Card] = [OPP(), OPP(), N(S,6), N(H,7), N(C,9), N(D,11), N(S,13), N(H,14)]
	for c in crafted:
		player.hand.append(c)
	for k in range(crafted.size()):
		sm.deck.cards.pop_back() # remove equivalent real cards from tracking
	sm.state = GameStateMachine.State.PLAYING
	sm.current_seat = 0
	sm.discard_pile.clear()
	sm.dead_pile.clear()

	var opp1: Card = player.hand[0]
	sm._execute_discard(opp1)
	expect(player.hand.size() == 7, "opp-chain-hand-7", "hand=" + str(player.hand.size()))
	var opp_in_dead := 0
	for c in sm.dead_pile:
		if c.is_opportunity(): opp_in_dead += 1
	expect(opp_in_dead == 2, "opp-chain-dead-2", "dead_opps=" + str(opp_in_dead))
	expect(total_tracked_cards(sm) == 84, "opp-chain-conservation", "total=" + str(total_tracked_cards(sm)))
	expect(not sm.deck.is_empty(), "opp-chain-deck-ok")

	# Single opportunity, no chain: deck loses exactly 1 net card (4 popped, 3 returned)
	var sm2 = GameStateMachine.new(GameRules.get_room("beginner"), true)
	sm2.setup_game(200000, 200000)
	sm2.deck.reset(6)
	var p2: PlayerState = sm2.players[0]
	p2.hand.clear()
	var crafted2: Array[Card] = [OPP(), N(S,6), N(H,7), N(C,9), N(D,11), N(S,13), N(H,13), N(D,14)]
	for c in crafted2:
		p2.hand.append(c)
	for k in range(crafted2.size()):
		sm2.deck.cards.pop_back()
	sm2.state = GameStateMachine.State.PLAYING
	sm2.current_seat = 0
	sm2.discard_pile.clear(); sm2.dead_pile.clear()
	var deck_before: int = sm2.deck.remaining_count()
	sm2._execute_discard(p2.hand[0])
	expect(p2.hand.size() == 7, "opp-single-hand-7", "hand=" + str(p2.hand.size()))
	expect(sm2.deck.remaining_count() == deck_before - 1, "opp-single-deck-net",
		"before=" + str(deck_before) + " after=" + str(sm2.deck.remaining_count()))
	expect(total_tracked_cards(sm2) == 84, "opp-single-conservation",
		"total=" + str(total_tracked_cards(sm2)))

func test_opportunity_blocks_hu_count() -> void:
	# 7 scoring cards (valid pattern) + 1 opportunity = NOT hu
	var hand: Array[Card] = [N(S,11), N(H,11), N(C,11), N(S,9), N(S,8), N(S,7), N(H,6), OPP()]
	expect(not HandEvaluator.evaluate_hand(hand, [12, 13, 14]).valid, "opp-blocks-hu")

# ---------------- settlement / bankruptcy ----------------
func test_settlement_bankruptcy() -> void:
	var sm = GameStateMachine.new(GameRules.get_room("beginner"), true)
	sm.setup_game(200000, 200000)
	# Winner: 8-set of A (score 112); loser seat1 rich, seat2 poor (100 beans), seat3 bankrupt
	var winner: PlayerState = sm.players[0]
	winner.hand.clear()
	for i in range(8): winner.hand.append(N(i % 4, 14))
	sm.players[1].hand.clear()
	for i in range(7): sm.players[1].hand.append(N(i % 4, 6 + i))
	sm.players[2].hand.clear()
	for i in range(7): sm.players[2].hand.append(N(i % 4, 6 + i))
	sm.players[2].beans = 100
	sm.players[3].is_bankrupt = true
	sm.players[3].hand.clear()
	for i in range(7): sm.players[3].hand.append(N(i % 4, 6 + i))

	var res = HandEvaluator.evaluate_hand(winner.hand, [6, 7, 9], {"self_draw": true})
	var bankrupt_seats: Array = []
	sm.player_bankrupt.connect(func(seat: int): bankrupt_seats.append(seat))
	sm._execute_hu(0, res)

	expect(winner.auto_hu and winner.hu_count == 1 and winner.has_hu, "hu-flags-set")
	# seat2 capped to 100 beans -> bankrupt
	expect(sm.players[2].beans == 0 and sm.players[2].is_bankrupt, "poor-loser-bankrupt",
		"beans=" + str(sm.players[2].beans))
	expect(bankrupt_seats.has(2), "bankrupt-signal")
	# bankrupt seat3 not charged
	expect(sm.players[3].round_net_beans == 0, "bankrupt-loser-skipped")
	# conservation: winner gain == losers loss
	var net := 0
	for p in sm.players: net += p.round_net_beans
	expect(net == 0, "settle-conservation", "net=" + str(net))

# ---------------- multi-hu blood flow ----------------
func test_multi_hu_blood_flow() -> void:
	var sm = GameStateMachine.new(GameRules.get_room("beginner"), true)
	sm.setup_game(200000, 200000)
	var winner: PlayerState = sm.players[1]
	for p in sm.players:
		p.hand.clear()
		for i in range(7): p.hand.append(N(i % 4, 6 + i))
	winner.hand.clear()
	for i in range(8): winner.hand.append(N(i % 4, 12 + (i % 2))) # Q/A mix, decomposes below

	# Use a guaranteed valid hu hand: 8x K
	winner.hand.clear()
	for i in range(8): winner.hand.append(N(i % 4, 13))
	var res = HandEvaluator.evaluate_hand(winner.hand, [6, 7, 9], {"self_draw": true})
	expect(res.valid, "blood-hu-valid")

	var hu_events: Array = [0] # array wrapper: GDScript lambda captures primitives by value
	sm.hu_settled.connect(func(a, b, c): hu_events[0] += 1)
	sm._execute_hu(1, res)
	sm._execute_hu(1, res) # second hu (blood flow allows repeated hu)
	expect(winner.hu_count == 2, "blood-hu-count-2", "count=" + str(winner.hu_count))
	expect(hu_events[0] == 2, "blood-hu-events-2", "events=" + str(hu_events[0]))
	var net := 0
	for p in sm.players: net += p.round_net_beans
	expect(net == 0, "blood-conservation", "net=" + str(net))

# ---------------- end game idempotence ----------------
func test_end_game_idempotent() -> void:
	var sm = GameStateMachine.new(GameRules.get_room("beginner"), true)
	sm.setup_game(200000, 200000)
	sm.start_round(11)
	var over_count: Array = [0]
	sm.game_over.connect(func(s): over_count[0] += 1)
	sm._end_game()
	sm._end_game()
	sm.advance_to_next_turn() # must not re-trigger end game
	expect(over_count[0] == 1, "end-game-once", "count=" + str(over_count[0]))
	expect(sm.state == GameStateMachine.State.GAME_OVER_STATE, "end-state")

# ---------------- dead pile ----------------
func test_dead_pile_tracking() -> void:
	var sm = GameStateMachine.new(GameRules.get_room("beginner"), true)
	sm.setup_game(200000, 200000)
	sm.deck.reset(3)
	var player: PlayerState = sm.players[0]
	player.hand.clear()
	for i in range(7): player.hand.append(N(i % 4, 6 + i))
	sm.state = GameStateMachine.State.PLAYING
	sm.current_seat = 0
	sm.discard_pile.clear(); sm.dead_pile.clear()
	# Discard 6 normal cards -> river holds 4, 2 overflow to dead pile
	for k in range(6):
		var c: Card = player.hand[0]
		sm._execute_discard(c)
		# refill hand to 7 to keep discarding (simulating draws)
		player.hand.append(N(k % 4, 10))
	expect(sm.discard_pile.size() == 4, "river-window-4", "river=" + str(sm.discard_pile.size()))
	expect(sm.dead_pile.size() == 2, "overflow-to-dead", "dead=" + str(sm.dead_pile.size()))
