import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    code = f.read()

# Remove multiple declarations
code = re.sub(r'(var prompt_label: Label\n)+', 'var prompt_label: Label\n', code)

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.write(code)
