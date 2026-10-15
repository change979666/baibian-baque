extends SceneTree
## Scratch probe: find a reproducible AI livelock and dump its cycle structure.
## Global RNG is explicitly seeded so (gseed, round_idx) fully determines a run.
## For each livelock round we record:
##  - whether the FULL spec fingerprint (incl. hu_count) ever repeats
##  - whether the LITE fingerprint (excl. hu_count) repeats, cycle start/period
##  - hu events inside the cycle (seat, payout) — does the cycle contain hus?

const TURN_CAP := 4000
const ITER_CAP := 200000

func _sig(sm: GameStateMachine, include_hu_count: bool) -> String:
	var parts: PackedStringArray = []
	parts.append(str(sm.current_seat))
	for p in sm.players:
		var h: PackedStringArray = []
		for c in p.hand:
			h.append(str(c.id))
		parts.append("H" + str(p.seat_idx) + ":" + ",".join(h))
		parts.append("B" + str(p.beans))
		parts.append("K" + str(int(p.is_bankrupt)) + str(int(p.has_hu)) + str(int(p.auto_hu)))
		if include_hu_count:
			parts.append("C" + str(p.hu_count))
	var dk: PackedStringArray = []
	for c in sm.deck.cards:
		dk.append(str(c.id))
	parts.append("D" + ",".join(dk))
	var rv: PackedStringArray = []
	for c in sm.discard_pile:
		rv.append(str(c.id))
	parts.append("R" + ",".join(rv))
	var dd: PackedStringArray = []
	for c in sm.dead_pile:
		dd.append(str(c.id))
	dd.sort()
	parts.append("X" + ",".join(dd))
	var g: PackedStringArray = []
	for r in sm.gold_mgr.gold_ranks:
		g.append(str(r))
	parts.append("G" + ",".join(g))
	parts.append("S" + str(sm.state))
	return "|".join(parts)

func _init() -> void:
	var room = GameRules.get_room("normal")
	var found := 0
	for gseed in range(1, 200):
		if found >= 2:
			break
		seed(gseed)
		for round_idx in range(400):
			var sm = GameStateMachine.new(room, true)
			sm.setup_game(200000, 200000)
			var hu_log: Array = []
			sm.hu_settled.connect(func(seat: int, eval_res: HandEvaluator.HandEvalResult, deltas: Dictionary):
				var tot := 0
				for k in deltas.keys():
					tot += abs(int(deltas[k]))
				hu_log.append({"seat": seat, "pay": tot})
			)
			sm.start_round(round_idx * 7 + 1)
			var lite_seen: Dictionary = {}
			var full_seen: Dictionary = {}
			var lite_repeat: Array = []  # [first_idx, repeat_idx]
			var full_repeat: Array = []
			var turns := 0
			var iterations := 0
			var livelock := false
			while sm.state != GameStateMachine.State.GAME_OVER_STATE:
				iterations += 1
				if iterations > ITER_CAP:
					break
				match sm.state:
					GameStateMachine.State.PLAYING:
						sm._process_turn()
					GameStateMachine.State.AWAITING_AI_ACTION, GameStateMachine.State.AWAITING_DRAW_SELECTION:
						var player: PlayerState = sm.players[sm.current_seat]
						if player.hand.size() == 7:
							var ls = _sig(sm, false)
							if lite_seen.has(ls) and lite_repeat.is_empty():
								lite_repeat = [lite_seen[ls], turns]
							lite_seen[ls] = turns
							var fs = _sig(sm, true)
							if full_seen.has(fs) and full_repeat.is_empty():
								full_repeat = [full_seen[fs], turns]
							full_seen[fs] = turns
							turns += 1
							sm.execute_ai_draw_selection()
						else:
							sm._execute_discard(AIAgent.choose_discard_card(player, sm.gold_mgr.gold_ranks))
					GameStateMachine.State.AWAITING_HUMAN_ACTION:
						sm._proceed_to_discard()
					_:
						break
				if turns > TURN_CAP:
					livelock = true
					break
			if iterations > ITER_CAP:
				livelock = true
			if livelock:
				found += 1
				print("=== LIVELOCK gseed=", gseed, " round_idx=", round_idx, " turns=", turns, " iters=", iterations)
				print("  deck=", sm.deck.remaining_count(), " river=", sm.discard_pile.size(), " dead=", sm.dead_pile.size())
				print("  beans=", [sm.players[0].beans, sm.players[1].beans, sm.players[2].beans, sm.players[3].beans])
				print("  hu_count=", [sm.players[0].hu_count, sm.players[1].hu_count, sm.players[2].hu_count, sm.players[3].hu_count])
				print("  total hu events=", hu_log.size())
				if lite_repeat.is_empty():
					print("  LITE fingerprint: NO repeat in ", turns, " turns")
				else:
					var cyc_start: int = lite_repeat[0]
					var cyc_end: int = lite_repeat[1]
					print("  LITE fingerprint repeat: cycle turns [", cyc_start, " .. ", cyc_end, ") period=", cyc_end - cyc_start)
					var hus_in_cycle := 0
					var pay_in_cycle := 0
					# hu_log has no turn index; approximate: count hus after cycle start proportionally
					# instead: count total payouts in whole round and hus
					for h in hu_log:
						pay_in_cycle += h["pay"]
					print("  (hus total=", hu_log.size(), " total payout=", pay_in_cycle, ")")
				if full_repeat.is_empty():
					print("  FULL fingerprint (incl hu_count): NO repeat")
				else:
					print("  FULL fingerprint repeat at turns ", full_repeat)
				# payout structure of last 50 hu events
				var tail_zero := 0
				var tail_n := 0
				for i in range(max(0, hu_log.size() - 50), hu_log.size()):
					tail_n += 1
					if hu_log[i]["pay"] == 0:
						tail_zero += 1
				print("  last-50 hus: zero-payout=", tail_zero, "/", tail_n)
				break  # next gseed
	print("PROBE DONE, livelocks found: ", found)
	quit(0)
