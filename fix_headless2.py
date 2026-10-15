import re

with open("src/system/game_state_machine.gd", "r", encoding="utf-8") as f:
    code = f.read()

# Fix _finish_turn
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

code = re.sub(pattern, replacement, code, flags=re.DOTALL)

# Same for execute_ai_draw_selection in _process_turn
pattern3 = r"""		if is_headless:
			execute_ai_draw_selection\(\)"""
replacement3 = """		if is_headless:
			pass # Handled by test loop"""
code = re.sub(pattern3, replacement3, code, flags=re.DOTALL)

with open("src/system/game_state_machine.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("Updated sm for headless loop again")
