extends SceneTree
## Focused probe: what actually distinguishes the 6 livelock rounds from normal play?
## For ALL rounds (guard off): track max streak of "no-progress" turns under two
## candidate definitions:
##   S1: deck count unchanged (chi-recycling only)
##   S3: deck unchanged AND dead unchanged AND no bankruptcy AND no new all-time-min beans
## For the 6 known livelock rounds: full per-turn fingerprint sighting stats +
## window analysis (user-spec stalemate incl. "no new hu" vs amended definitions).

const ROUNDS := 1500
const GSEED := 3
const TURN_CAP := 4000
const ITER_CAP := 200000
const TARGETS := [146, 215, 471, 489, 1460, 1498]

func _init() -> void:
	print("====== STAGNATION PROBE ======")
	var t0: int = Time.get_ticks_msec()
	seed(GSEED)
	var room = GameRules.get_room("normal")

	var max_s1_normal := 0
	var max_s3_normal := 0
	var s1_hist: Dictionary = {} # bucketed max-S1 for normal rounds
	var results: Array = []

	for round_idx in range(ROUNDS):
		var is_target: bool = round_idx in TARGETS
		var sm = GameStateMachine.new(room, true)
		sm.setup_game(200000, 200000)
		sm.guard_enabled = false
		sm.start_round(round_idx * 7 + 1)

		var last_deck: int = sm.deck.remaining_count()
		var last_dead: int = sm.dead_pile.size()
		var min_beans_seen: int = 1 << 60
		var s1 := 0
		var s3 := 0
		var max_s1 := 0
		var max_s3 := 0
		var hu_total := 0

		# target-round instrumentation
		var fp_seen: Dictionary = {}      # fp -> array of sighting turns (targets only)
		var progress_free_with_hu := 0    # window where deck/dead/bankrupt/hu ALL unchanged (user spec)
		var max_progress_free_with_hu := 0
		var last_hu := 0
		var sm_weak: WeakRef = weakref(sm)
		var ctx: Array = [0] # mutable holders not needed; use locals via arrays below
		var state_holder: Dictionary = {"s1": 0, "s3": 0, "max_s1": 0, "max_s3": 0,
			"min_beans": 1 << 60, "last_deck": last_deck, "last_dead": last_dead,
			"last_bankrupt": 0, "last_hu": 0, "pfh": 0, "max_pfh": 0}
		sm.turn_completed.connect(func(tc: int):
			var smr: GameStateMachine = sm_weak.get_ref()
			if smr == null:
				return
			var deck_now: int = smr.deck.remaining_count()
			var dead_now: int = smr.dead_pile.size()
			var hu_now := 0
			var bankrupt_now := 0
			var beans_min_now: int = 1 << 60
			for p in smr.players:
				hu_now += p.hu_count
				if p.is_bankrupt:
					bankrupt_now += 1
				if p.beans < beans_min_now:
					beans_min_now = p.beans
			# S1: deck unchanged
			if deck_now == int(state_holder["last_deck"]):
				state_holder["s1"] = int(state_holder["s1"]) + 1
			else:
				state_holder["s1"] = 0
			state_holder["max_s1"] = maxi(int(state_holder["max_s1"]), int(state_holder["s1"]))
			# S3: deck/dead/bankrupt unchanged AND no new all-time-min beans
			var new_min: bool = beans_min_now < int(state_holder["min_beans"])
			if new_min:
				state_holder["min_beans"] = beans_min_now
			if deck_now == int(state_holder["last_deck"]) and dead_now == int(state_holder["last_dead"]) \
				and bankrupt_now == int(state_holder["last_bankrupt"]) and not new_min:
				state_holder["s3"] = int(state_holder["s3"]) + 1
			else:
				state_holder["s3"] = 0
			state_holder["max_s3"] = maxi(int(state_holder["max_s3"]), int(state_holder["s3"]))
			# user-spec stalemate progress-free window (also requires no new hu)
			if deck_now == int(state_holder["last_deck"]) and dead_now == int(state_holder["last_dead"]) \
				and bankrupt_now == int(state_holder["last_bankrupt"]) and hu_now == int(state_holder["last_hu"]):
				state_holder["pfh"] = int(state_holder["pfh"]) + 1
			else:
				state_holder["pfh"] = 0
			state_holder["max_pfh"] = maxi(int(state_holder["max_pfh"]), int(state_holder["pfh"]))
			state_holder["last_deck"] = deck_now
			state_holder["last_dead"] = dead_now
			state_holder["last_bankrupt"] = bankrupt_now
			state_holder["last_hu"] = hu_now
			if IS_TARGET(round_idx):
				var fp: String = smr._state_fingerprint()
				if not fp_seen.has(fp):
					fp_seen[fp] = []
				fp_seen[fp].append(tc)
		)

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

		if is_target:
			# fingerprint sighting analysis
			var best_fp := ""
			var best_count := 0
			for fp in fp_seen.keys():
				if fp_seen[fp].size() > best_count:
					best_count = fp_seen[fp].size()
					best_fp = fp
			var gaps: PackedStringArray = []
			if best_count > 1:
				var turns_arr: Array = fp_seen[best_fp]
				for i in range(1, mini(turns_arr.size(), 12)):
					gaps.append(str(int(turns_arr[i]) - int(turns_arr[i - 1])))
			results.append({
				"round": round_idx, "verdict": verdict, "turns": sm.turn_count,
				"max_s1": state_holder["max_s1"], "max_s3": state_holder["max_s3"],
				"max_pfh": state_holder["max_pfh"],
				"unique_fps": fp_seen.size(), "best_fp_count": best_count,
				"best_fp_gaps": ",".join(gaps),
				"hu_total": state_holder["last_hu"],
				"beans": [sm.players[0].beans, sm.players[1].beans, sm.players[2].beans, sm.players[3].beans]
			})
		else:
			var m1: int = state_holder["max_s1"]
			var m3: int = state_holder["max_s3"]
			max_s1_normal = maxi(max_s1_normal, m1)
			max_s3_normal = maxi(max_s3_normal, m3)
			var bucket: int = clampi(m3 / 16, 0, 100)
			s1_hist[bucket] = int(s1_hist.get(bucket, 0)) + 1

		if (round_idx + 1) % 250 == 0:
			print("  ... ", round_idx + 1, " / ", ROUNDS, " (", Time.get_ticks_msec() - t0, " ms)")

	print("====== RESULTS ======")
	print("-- normal rounds (", ROUNDS - TARGETS.size(), ") --")
	print("max S1 streak (deck unchanged): ", max_s1_normal)
	print("max S3 streak (deck+dead+bankrupt+no-new-min-beans): ", max_s3_normal)
	print("S3 histogram (bucket = streak/16):")
	var keys: Array = s1_hist.keys()
	keys.sort()
	for k in keys:
		print("   ", int(k) * 16, "-", int(k) * 16 + 15, ": ", s1_hist[k])
	print("-- livelock rounds --")
	for r in results:
		print("round ", r["round"], " verdict=", r["verdict"], " turns=", r["turns"],
			"\n   maxS1=", r["max_s1"], " maxS3=", r["max_s3"], " maxPFH(user-spec)=", r["max_pfh"],
			"\n   unique_fps=", r["unique_fps"], " best_fp_seen=", r["best_fp_count"], " gaps=[", r["best_fp_gaps"], "]",
			"\n   hu_total=", r["hu_total"], " beans=", r["beans"])
	print("elapsed: ", Time.get_ticks_msec() - t0, " ms")
	quit(0)

func IS_TARGET(round_idx: int) -> bool:
	return round_idx in TARGETS
