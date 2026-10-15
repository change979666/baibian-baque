extends SceneTree
## LIV-001 shadow experiment: guard stays OFF (zero trajectory divergence).
## Records the turn-boundary fingerprint sequence of every round, then offline
## computes the longest run of CONSECUTIVE EQUIDISTANT sightings per fingerprint.
## FP(K) = rounds that would fire at threshold K but ended normally.
## TP(K) = true livelock rounds (>TURN_CAP turns) that would fire at K.
## Same GSEED as the A/B experiment -> identical round trajectories to pass A.

const ROUNDS := 1500
const GSEED := 3
const TURN_CAP := 4000
const ITER_CAP := 200000
const K_MIN := 2
const K_MAX := 8

func _init() -> void:
	print("====== GUARD SHADOW EXPERIMENT: ", ROUNDS, " rounds, gseed=", GSEED, " ======")
	var t0: int = Time.get_ticks_msec()
	seed(GSEED)
	var room = GameRules.get_room("normal")

	var fp_counts: Array = []      # K index -> FP count
	var tp_counts: Array = []      # K index -> TP count
	var miss_counts: Array = []    # K index -> miss count
	var fire_turns: Array = []     # K index -> cumulative detection turns (for TP)
	var livelock_rounds := 0
	var worst_fp: Dictionary = {}  # K -> array of round indices

	for k in range(K_MIN, K_MAX + 1):
		fp_counts.append(0)
		tp_counts.append(0)
		miss_counts.append(0)
		fire_turns.append(0)
		worst_fp[k] = []

	for round_idx in range(ROUNDS):
		var sm = GameStateMachine.new(room, true)
		sm.setup_game(200000, 200000)
		sm.guard_enabled = false # shadow only
		sm.start_round(round_idx * 7 + 1)

		# per-round fingerprint observation state
		var last_turn: Dictionary = {}  # fp -> last sighting turn
		var last_gap: Dictionary = {}   # fp -> current gap of the equidistant run
		var run_len: Dictionary = {}    # fp -> sightings in current equidistant run
		var fire_turn: Dictionary = {}  # K -> first turn maxrun reached K
		for k in range(K_MIN, K_MAX + 1):
			fire_turn[k] = -1
		var sm_weak: WeakRef = weakref(sm)
		var obs: Array = [last_turn, last_gap, run_len, fire_turn]
		sm.turn_completed.connect(func(tc: int):
			var smr: GameStateMachine = sm_weak.get_ref()
			if smr == null:
				return
			var fp: String = smr._state_fingerprint()
			var lt: Dictionary = obs[0]
			var lg: Dictionary = obs[1]
			var rl: Dictionary = obs[2]
			var ft: Dictionary = obs[3]
			if not lt.has(fp):
				lt[fp] = tc
				lg[fp] = 0
				rl[fp] = 1
			else:
				var gap: int = tc - int(lt[fp])
				if int(lg[fp]) == 0:
					lg[fp] = gap
					rl[fp] = 2
				elif gap == int(lg[fp]):
					rl[fp] = int(rl[fp]) + 1
				else:
					lg[fp] = gap
					rl[fp] = 2
				lt[fp] = tc
			var r: int = int(rl[fp])
			for k in range(K_MIN, K_MAX + 1):
				if r >= k and int(ft[k]) == -1:
					ft[k] = tc
		)

		# drive (identical to mass sim / A/B)
		var iterations := 0
		var verdict := "OK"
		while sm.state != GameStateMachine.State.GAME_OVER_STATE:
			iterations += 1
			if iterations > ITER_CAP:
				verdict = "ITER_CAP"
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
					verdict = "BAD_STATE"
					break
			if sm.turn_count > TURN_CAP:
				verdict = "TURN_CAP"
				break

		var is_livelock: bool = (verdict != "OK")
		if is_livelock:
			livelock_rounds += 1
		for k in range(K_MIN, K_MAX + 1):
			var ki: int = k - K_MIN
			var fired: bool = (int(fire_turn[k]) != -1)
			if fired and not is_livelock:
				fp_counts[ki] += 1
				worst_fp[k].append(round_idx)
			elif fired and is_livelock:
				tp_counts[ki] += 1
				fire_turns[ki] += int(fire_turn[k])
			elif not fired and is_livelock:
				miss_counts[ki] += 1

		if (round_idx + 1) % 250 == 0:
			print("  ... ", round_idx + 1, " / ", ROUNDS, " (", Time.get_ticks_msec() - t0, " ms)")

	print("====== SHADOW RESULT (rounds=", ROUNDS, ", livelocks=", livelock_rounds, ") ======")
	print("K\tFP(ended normal)\tTP(livelock caught)\tMISS\tavg TP fire turn")
	for k in range(K_MIN, K_MAX + 1):
		var ki: int = k - K_MIN
		var avg_fire := 0.0
		if tp_counts[ki] > 0:
			avg_fire = float(fire_turns[ki]) / tp_counts[ki]
		print(k, "\t", fp_counts[ki], "\t", tp_counts[ki], " / ", livelock_rounds, "\t", miss_counts[ki], "\t", snapped(avg_fire, 0.1))
	for k in range(K_MIN, K_MAX + 1):
		if worst_fp[k].size() > 0:
			print("  FP rounds @K=", k, " (", worst_fp[k].size(), "): ", str(worst_fp[k]).left(200))
	print("elapsed: ", Time.get_ticks_msec() - t0, " ms")
	quit(0)
