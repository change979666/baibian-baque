import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

code = code.replace(
"""	var river_idx = max(0, discard_container.get_child_count() - 1)
	var col = river_idx % 8
	var row = river_idx / 8
	var river_gpos = discard_panel.global_position + Vector2(10 + col * 54, 10 + row * 70)""",
"""	var river_idx = max(0, discard_container.get_child_count() - 1)
	var river_gpos = Vector2(460 + river_idx * 98, 244)"""
)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)
