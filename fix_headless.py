import re

with open("src/system/game_state_machine.gd", "r", encoding="utf-8") as f:
    code = f.read()

# Remove the recursive calls in headless
pattern = r"""	if is_headless:
		if get_active_players_count\(\) <= 1:
			_end_game\(\)
			return
		var next_s = get_next_active_seat\(current_seat\)
		if next_s == -1 or get_active_players_count\(\) <= 1:
			_end_game\(\)
			return
		current_seat = next_s
		state = State.PLAYING
		_process_turn\(\)"""

replacement = """	if is_headless:
		if get_active_players_count() <= 1:
			_end_game()
			return
		var next_s = get_next_active_seat(current_seat)
		if next_s == -1 or get_active_players_count() <= 1:
			_end_game()
			return
		current_seat = next_s
		state = State.PLAYING"""

code = code.replace(pattern, replacement)

# We also need to remove the recursive call in `_proceed_to_discard`
# Wait, `_proceed_to_discard` sets state to AWAITING_AI_ACTION and calls `execute_ai_discard(discard)` when headless.
# Let's NOT call it directly. Just let it return.
pattern2 = r"""		if is_headless:
			var discard = AIAgent.choose_discard_card\(player, gold_mgr.gold_ranks\)
			_execute_discard\(discard\)"""
replacement2 = """		if is_headless:
			pass # Will be handled by the test loop"""
code = code.replace(pattern2, replacement2)

# Same for execute_ai_draw_selection in _process_turn
pattern3 = r"""		if is_headless:
			execute_ai_draw_selection\(\)"""
replacement3 = """		if is_headless:
			pass # Handled by test loop"""
code = code.replace(pattern3, replacement3)

with open("src/system/game_state_machine.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("Updated sm for headless loop")
