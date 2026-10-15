import re

with open("src/system/game_state_machine.gd", "r", encoding="utf-8") as f:
    code = f.read()

# 1. Replace State Enum
code = code.replace(
    "AWAITING_HUMAN_CHI,",
    "AWAITING_DRAW_SELECTION,\n\tAWAITING_AI_ACTION,"
)

# 2. Replace _process_turn and everything up to _execute_hu
pattern = r"func _process_turn\(\) -> void:.*?func human_declare_hu\(\) -> void:"
replacement = """func _process_turn() -> void:
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

	if player.is_human and not is_headless and not player.auto_hu:
		state = State.AWAITING_DRAW_SELECTION
		emit_signal("chi_prompt_requested", current_seat, null, []) # Signal UI to allow draw selection
	else:
		state = State.AWAITING_AI_ACTION
		if is_headless:
			execute_ai_draw_selection()
		else:
			emit_signal("ai_turn_ready", current_seat)

func execute_ai_draw_selection() -> void:
	var player = players[current_seat]
	var chosen_card = null
	
	# Evaluate river cards to see if any forms a chi/combo
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

func human_claim_chi(card: Card) -> void:
	if state != State.AWAITING_DRAW_SELECTION:
		return
	if card == null:
		_execute_draw_from_deck()
	else:
		_execute_draw_from_river(card)

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

func human_declare_hu() -> void:"""

code = re.sub(pattern, replacement, code, flags=re.DOTALL)

# 3. Replace _proceed_to_discard emitting ai_turn_ready to set AWAITING_AI_ACTION
pattern2 = r"func _proceed_to_discard\(\) -> void:.*?func execute_ai_discard\(\) -> void:"
replacement2 = """func _proceed_to_discard() -> void:
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
			var discard = AIAgent.choose_discard_card(player, gold_mgr.gold_ranks)
			_execute_discard(discard)
		else:
			emit_signal("ai_turn_ready", current_seat)

func execute_ai_discard() -> void:"""
code = re.sub(pattern2, replacement2, code, flags=re.DOTALL)

with open("src/system/game_state_machine.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("Updated game_state_machine.gd")
