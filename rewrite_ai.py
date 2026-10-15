import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

pattern = r"func _on_ai_turn_ready\(seat: int\) -> void:.*?sm\.execute_ai_discard\(\)\n\t\)"
replacement = """func _on_ai_turn_ready(seat: int) -> void:
	if sm.is_headless:
		return
	
	var think_time = randf_range(0.55, 0.75)
	var tween = create_tween()
	tween.tween_interval(think_time)
	tween.tween_callback(func():
		var player = sm.players[seat]
		if player.hand.size() == 7:
			sm.execute_ai_draw_selection()
		else:
			sm.execute_ai_discard()
	)"""

code = re.sub(pattern, replacement, code, flags=re.DOTALL)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)
print("Updated ai_turn_ready")
