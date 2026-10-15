import re

with open("src/system/game_state_machine.gd", "r", encoding="utf-8") as f:
    code = f.read()

pattern2 = r"""		if is_headless:
			var discard = AIAgent\.choose_discard_card\(player, gold_mgr\.gold_ranks\)
			_execute_discard\(discard\)"""
replacement2 = """		if is_headless:
			pass # Will be handled by the test loop"""
code = re.sub(pattern2, replacement2, code, flags=re.DOTALL)

with open("src/system/game_state_machine.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("Updated sm discard for headless loop")
