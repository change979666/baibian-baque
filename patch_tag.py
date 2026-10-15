import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

code = code.replace(
"""	if sm and sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION:
		action_tag.text = "可拿"
		action_tag.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		action_tag.visible = true""",
"""	if sm and sm.state == GameStateMachine.State.AWAITING_DRAW_SELECTION:
		action_tag.text = "吃"
		action_tag.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		action_tag.visible = true"""
)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)
