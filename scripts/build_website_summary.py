#!/usr/bin/env python3
"""
Parse a release notes markdown file and output a JSON summary for
the website dispatch payload.

Usage:
    python3 scripts/build_website_summary.py <notes-file>

Outputs a single JSON line to stdout:
    {"change_type": "fix", "desc_en": "...", "desc_zh": "..."}
"""
import json
import re
import sys
from pathlib import Path


def parse_summary(notes_file: str) -> dict:
    text = Path(notes_file).read_text(encoding="utf-8")

    # Split into sections by ### headings
    sections: dict[str, list[str]] = {}
    current = None
    for line in text.splitlines():
        if line.startswith("### "):
            current = line.strip()
            sections[current] = []
        elif current is not None:
            sections[current].append(line.rstrip())

    # Prefer "New Features" over "Bug Fixes"
    if "### New Features / 新功能" in sections:
        target_heading = "### New Features / 新功能"
        change_type = "feat"
    else:
        target_heading = "### Bug Fixes / 问题修复"
        change_type = "fix"

    target_lines = sections.get(target_heading, [])

    # Lines indented with 2+ spaces are sub-bullet descriptions
    indented = [line.strip() for line in target_lines if line.startswith("  ") and line.strip()]

    # Pick first English and first Chinese description line
    desc_en = next((line for line in indented if not re.search(r"[\u4e00-\u9fff]", line)), "")
    desc_zh = next((line for line in indented if re.search(r"[\u4e00-\u9fff]", line)), "")

    # Fallback: use the first "- **Title**" bullet as desc_en
    if not desc_en:
        desc_en = next(
            (
                re.sub(r"^- \*\*(.+?)\*\*$", r"\1", line.strip())
                for line in target_lines
                if line.strip().startswith("- **")
            ),
            "",
        )

    # Fallback: use first indented line as desc_zh
    if not desc_zh:
        desc_zh = next((line for line in indented if line), "")

    return {
        "change_type": change_type,
        "desc_en": desc_en,
        "desc_zh": desc_zh,
    }


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <notes-file>", file=sys.stderr)
        sys.exit(1)

    result = parse_summary(sys.argv[1])
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
