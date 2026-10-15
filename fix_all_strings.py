#!/usr/bin/env python3
"""
Scan table_view.gd for lines with mojibake (corrupted Chinese) and fix them.
Also fix the missing btn_refill_resume declaration and _on_chi_prompt_requested reference.
"""
import re

with open("src/ui/table_view.gd", "r", encoding="utf-8") as f:
    lines = f.readlines()

# Detect mojibake: lines containing sequences of CJK Compatibility Ideographs
# or garbled multi-byte that aren't valid Chinese
# We look for lines with common mojibake patterns

fixes = {}
for i, line in enumerate(lines):
    lineno = i + 1
    stripped = line.rstrip('\r\n')
    
    # Check for common mojibake markers
    has_mojibake = False
    for ch in stripped:
        cp = ord(ch)
        # Common mojibake ranges: these are valid Unicode but contextually wrong
        # 鐗 鎵 銆 鑳 瀹 etc appear in mojibake of Chinese encoded as latin1->utf8
        if cp >= 0x9000 and cp <= 0x9FFF:
            # Check if context seems garbled (multiple consecutive rare chars)
            pass
    
    # Instead of heuristic, let's just look for specific known broken patterns
    # and replace them with correct Chinese text
    
# Actually, let's take a smarter approach: find lines that have unmatched quotes
# (the core syntax issue) and also lines with known broken text patterns

broken_lines = []
for i, line in enumerate(lines):
    lineno = i + 1
    stripped = line.rstrip('\r\n')
    
    # Count unescaped quotes
    in_string = False
    quote_count = 0
    j = 0
    while j < len(stripped):
        ch = stripped[j]
        if ch == '\\' and j + 1 < len(stripped) and stripped[j+1] == '"':
            j += 2  # skip escaped quote
            continue
        if ch == '"':
            quote_count += 1
        j += 1
    
    if quote_count % 2 != 0:
        broken_lines.append((lineno, stripped))
        print(f"Line {lineno} has odd quotes ({quote_count}): {stripped[:80]}...")

print(f"\nTotal broken lines: {len(broken_lines)}")
