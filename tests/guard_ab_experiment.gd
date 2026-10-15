extends SceneTree
## LIV-001 guard A/B experiment: measures TRUE false-positive and miss rates.
## Pass A: guard OFF, turn cap 4000 -> rounds exceeding cap are true livelocks.
## Pass B: guard ON (same global seed -> identical trajectories until any trigger).
##   - guard fires & Pass A ended normally  => FALSE POSITIVE
##   - Pass A livelocked & guard stayed silent => MISS
##   - Pass A livelocked & guard fired        => TRUE POSITIVE (record turn saved)

const ROUNDS := 1500
const GSEED := 3
const TURN_CAP := 4000
const ITER_CAP := 200000

func _drive(sm: GameStateMachine) -> String:
	var iterations := 0
	while sm.state != GameStateMachine.State.GAME_OVER_STATE:
		iterations += 1
		if iterations > ITER_CAP:
			return "ITER_CAP"
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
				return "BAD_STATE_" + str(sm.state)
		if sm.turn_count > TURN_CAP:
			return "TURN_CAP"
	return "OK"

func _run_pass(guard_on: bool) -> Dictionary:
	seed(GSEED)
	var room = GameRules.get_room("normal")
	var out: Dictionary = {}
	for round_idx in range(ROUNDS):
		var sm = GameStateMachine.new(room, true)
		sm.setup_game(200000, 200000)
		sm.guard_enabled = guard_on
		sm.start_round(round_idx * 7 + 1)
		var verdict = _drive(sm)
		out[round_idx] = {
			"verdict": verdict,
			"guard": sm.guard_reason,
			"turns": sm.turn_count,
			"hus": [sm.players[0].hu_count, sm.players[1].hu_count, sm.players[2].hu_count, sm.players[3].hu_count]
		}
	return out

func _init() -> void:
	print("====== GUARD A/B EXPERIMENT: ", ROUNDS, " rounds, gseed=", GSEED, " ======")
	var t0: int = Time.get_ticks_msec()
	print("--- Pass A: guard OFF (baseline) ---")
	var a := _run_pass(false)
	print("    pass A done in ", Time.get_ticks_msec() - t0, " ms")
	var t1: int = Time.get_ticks_msec()
	print("--- Pass B: guard ON ---")
	var b := _run_pass(true)
	print("    pass B done in ", Time.get_ticks_msec() - t1, " ms")

	var false_pos: Array = []
	var misses: Array = []
	var true_pos: Array = []
	var baseline_livelocks := 0
	var guard_triggers := {"STATE_CYCLE_GUARD": 0, "STALEMATE_GUARD": 0}
	for r in range(ROUNDS):
		var ra: Dictionary = a[r]
		var rb: Dictionary = b[r]
		var a_live: bool = (ra["verdict"] != "OK") # TURN_CAP/ITER_CAP = would not terminate
		if a_live:
			baseline_livelocks += 1
		var b_guard: String = rb["guard"]
		if b_guard != "":
			guard_triggers[b_guard] = int(guard_triggers.get(b_guard, 0)) + 1
		if b_guard != "" and not a_live:
			false_pos.append({"round": r, "reason": b_guard, "turns_b": rb["turns"], "turns_a": ra["turns"], "hus_b": rb["hus"]})
		elif a_live and b_guard == "":
			misses.append({"round": r, "verdict_a": ra["verdict"], "turns_b": rb["turns"]})
		elif a_live and b_guard != "":
			true_pos.append({"round": r, "reason": b_guard, "turns_b": rb["turns"], "verdict_a": ra["verdict"]})

	print("====== A/B RESULT ======")
	print("baseline livelocks (guard OFF, >", TURN_CAP, " turns): ", baseline_livelocks)
	print("guard triggers (pass B): STATE_CYCLE=", guard_triggers["STATE_CYCLE_GUARD"],
		" STALEMATE=", guard_triggers["STALEMATE_GUARD"])
	print("TRUE POSITIVES (livelock caught): ", true_pos.size())
	for tp in true_pos:
		print("  * round ", tp["round"], " -> ", tp["reason"], " at turn ", tp["turns_b"], " (baseline: ", tp["verdict_a"], ")")
	print("FALSE POSITIVES (guard fired on normal round): ", false_pos.size())
	for fp in false_pos:
		print("  * round ", fp["round"], " -> ", fp["reason"], " at turn ", fp["turns_b"],
			" (baseline ended OK at turn ", fp["turns_a"], ", hus=", fp["hus_b"], ")")
	print("MISSES (livelock not caught): ", misses.size())
	for m in misses:
		print("  * round ", m["round"], " baseline=", m["verdict_a"], " passB turns=", m["turns_b"])
	var ok: bool = false_pos.is_empty() and misses.is_empty()
	print("VERDICT: ", "CLEAN (0 FP, 0 miss)" if ok else "NEEDS TUNING")
	quit(0 if ok else 1)
