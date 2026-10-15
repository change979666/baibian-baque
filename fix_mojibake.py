#!/usr/bin/env python3
"""
Fix mojibake in table_view.gd caused by UTF-8 bytes being misread as GBK.
Recovery: encode mojibake chars as GBK -> get original UTF-8 bytes -> decode as UTF-8.
"""

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()

fixed_count = 0
failed_lines = []

for i, line in enumerate(lines):
    try:
        # Try to encode the line as GBK (to reverse the mojibake)
        # then decode as UTF-8 (to get the original Chinese text)
        recovered = line.encode("gbk").decode("utf-8")
        if recovered != line:
            lines[i] = recovered
            fixed_count += 1
            print(f"  FIXED line {i+1}: {recovered.strip()[:80]}")
    except (UnicodeEncodeError, UnicodeDecodeError):
        # Line contains chars that can't roundtrip through GBK
        # (e.g. emoji already fixed, or pure ASCII) - leave as is
        # But check if this line has odd quote count (broken string)
        stripped = line.rstrip("\r\n")
        quote_count = 0
        j = 0
        while j < len(stripped):
            if stripped[j] == "\\" and j + 1 < len(stripped) and stripped[j+1] == '"':
                j += 2
                continue
            if stripped[j] == '"':
                quote_count += 1
            j += 1
        if quote_count % 2 != 0:
            failed_lines.append((i+1, stripped[:100]))

print(f"\nFixed {fixed_count} lines via GBK->UTF-8 recovery")
if failed_lines:
    print(f"\nStill broken (odd quotes) - {len(failed_lines)} lines:")
    for ln, content in failed_lines:
        print(f"  Line {ln}: {content}")

with open("src/ui/table_view.gd", "w", encoding="utf-8") as f:
    f.writelines(lines)

print("\nDone. File saved.")
