#!/usr/bin/env python3
"""Lightweight Lua formatter to unify indentation and spacing."""
from __future__ import annotations

import argparse
import os
import sys
from typing import Iterable, List, Tuple

OPEN_KEYWORDS = {"then", "do", "function", "repeat"}
CLOSE_KEYWORDS = {"end", "until"}
LEADING_DEDENT_KEYWORDS = {"end", "elseif", "else", "until"}

def count_parens(line: str) -> Tuple[int, int]:
	in_string = None
	depth_open = 0
	depth_close = 0
	i = 0
	while i < len(line):
		ch = line[i]
		if in_string:
			if ch == "\\":
				i += 2
				continue
			if ch == in_string:
				in_string = None
			i += 1
			continue
		if ch in ('"', "'"):
			in_string = ch
			i += 1
			continue
		if ch == "(":
			depth_open += 1
		elif ch == ")":
			depth_close += 1
		i += 1
	return depth_open, depth_close


def _match_long_bracket(line: str, start: int) -> Tuple[int, int] | None:
	if line[start] != "[":
		return None
	i = start + 1
	while i < len(line) and line[i] == "=":
		i += 1
	if i < len(line) and line[i] == "[":
		return i + 1, i - start - 1
	return None


def _skip_long_bracket(line: str, start: int, eq_count: int) -> int:
	closing = "]" + "=" * eq_count + "]"
	idx = line.find(closing, start)
	if idx == -1:
		return len(line)
	return idx + len(closing)


def analyse_tokens(line: str) -> Tuple[str, int, int, int, int, int, int, bool]:
	stripped = line.strip()
	if not stripped:
		return "", 0, 0, 0, 0, 0, 0, True

	open_keywords = 0
	close_keywords = 0
	leading_keyword_dedent = 0
	open_braces = 0
	close_braces = 0
	leading_brace_dedent = 0
	trailing_closing_braces = 0

	i = 0
	length = len(line)
	in_string: str | None = None
	long_string_eq: int | None = None
	leading = True

	while i < length:
		ch = line[i]
		if in_string:
			if ch == "\\":
				i += 2
				continue
			if ch == in_string:
				in_string = None
				i += 1
				continue
			i += 1
			continue
		if long_string_eq is not None:
			i = _skip_long_bracket(line, i, long_string_eq)
			long_string_eq = None
			continue
		if ch in " \t":
			i += 1
			continue
		if ch == "-" and i + 1 < length and line[i + 1] == "-":
			break
		if ch in ('"', "'"):
			in_string = ch
			i += 1
			continue
		if ch == "[":
			match = _match_long_bracket(line, i)
			if match:
				i, eq = match
				long_string_eq = eq
				continue
		if ch.isalpha() or ch == "_":
			start = i
			while i < length and (line[i].isalnum() or line[i] == "_"):
				i += 1
			word = line[start:i].lower()
			if leading and word in LEADING_DEDENT_KEYWORDS:
				leading_keyword_dedent += 1
			if word == "elseif":
				close_keywords += 1
			elif word == "else":
				close_keywords += 1
				open_keywords += 1
			elif word in OPEN_KEYWORDS:
				open_keywords += 1
			elif word in CLOSE_KEYWORDS:
				close_keywords += 1
			leading = False
			continue
		if ch == "{":
			open_braces += 1
			leading = False
			i += 1
			continue
		if ch == "}":
			close_braces += 1
			if leading:
				leading_brace_dedent += 1
			trailing_closing_braces += 1
			leading = False
			i += 1
			continue
		leading = False
		trailing_closing_braces = 0
		i += 1

	return (
		stripped,
		open_keywords,
		close_keywords,
		leading_keyword_dedent,
		open_braces,
		close_braces,
		leading_brace_dedent,
		False,
	)


def count_leading_braces(line: str) -> int:
	count = 0
	stripped = line.lstrip()
	for ch in stripped:
		if ch == "}":
			count += 1
		else:
			break
	return count


def format_lines(lines: Iterable[str]) -> List[str]:
    formatted: List[str] = []
    indent = 0
    paren_depth = 0

    for line in lines:
        # Count parentheses BEFORE stripping whitespace
        open_p, close_p = count_parens(line)

        # Token analysis (keywords/braces)
        stripped, open_kw, close_kw, leading_kw_dedent, open_br, close_br, leading_br_dedent, is_blank = analyse_tokens(line)

        if is_blank:
            formatted.append("")
            continue

        leading_braces = count_leading_braces(line)

        # Determine if we are entering or inside a multiline parentheses block
        entering_paren = (paren_depth == 0 and open_p > close_p)
        inside_paren = (paren_depth > 0)

        # ---------- MULTILINE PARENTHESIS LOGIC ----------
        if inside_paren or entering_paren:
            # Compute new depth BEFORE output so closing paren aligns properly
            new_depth = paren_depth + open_p - close_p
            if new_depth < 0:
                new_depth = 0

            if entering_paren:
                # First line of the function call
                formatted.append("\t" * indent + stripped)

            else:
                # Inside parentheses block
                if stripped.endswith(")"):
                    # Look at the content BEFORE the closing paren
                    inner = stripped[:-1].rstrip()

                    if inner:
                        # CASE: mixed content + closing paren, e.g.
                        #   clamp01(blah))
                        # Emit argument on its own line
                        formatted.append("\t" * (indent + 1) + inner)
                        # Emit final ')' on its own line at base indent
                        formatted.append("\t" * indent + ")")
                    else:
                        # CASE: pure closing paren
                        formatted.append("\t" * indent + ")")
                else:
                    # Argument / table line: +1 indent
                    formatted.append("\t" * (indent + 1) + stripped)

            paren_depth = new_depth
            continue
        # --------------------------------------------------

        # ---------- NORMAL LUA INDENTATION LOGIC ----------
        indent = max(indent - leading_kw_dedent - leading_braces, 0)

        # Apply indentation
        formatted.append("\t" * indent + stripped)

        # Adjust indent based on keywords/braces
        indent += open_kw + open_br
        indent -= max(close_kw - leading_kw_dedent, 0)
        indent -= max(close_br - leading_braces, 0)

        if indent < 0:
            indent = 0

        # Update parentheses depth AFTER formatting normal line
        paren_depth += open_p - close_p
        if paren_depth < 0:
            paren_depth = 0
        # --------------------------------------------------

    return formatted


def process_file(path: str) -> bool:
    with open(path, "r", encoding="utf-8") as f:
        original_lines = f.read().splitlines()
    formatted_lines = format_lines(original_lines)

    # 🧹 Trim trailing spaces and remove blank lines at end of file
    formatted_lines = [line.rstrip() for line in formatted_lines]
    while formatted_lines and not formatted_lines[-1]:
        formatted_lines.pop()

    if formatted_lines == original_lines:
        return False

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(formatted_lines))
        f.write("\n")
    return True


def iter_lua_files(paths: List[str]) -> Iterable[str]:
	if paths:
		for path in paths:
			if os.path.isdir(path):
				for root, _, files in os.walk(path):
					for name in files:
						if name.endswith(".lua"):
							yield os.path.join(root, name)
			elif path.endswith(".lua"):
				yield path
	else:
		for root, _, files in os.walk("."):
			for name in files:
				if name.endswith(".lua"):
					yield os.path.join(root, name)


def main(argv: List[str]) -> int:
	parser = argparse.ArgumentParser(description="Format Lua files to a consistent style.")
	parser.add_argument("paths", nargs="*", help="Files or directories to format")
	args = parser.parse_args(argv)

	changed = False
	for path in iter_lua_files(args.paths):
		if process_file(path):
			print(f"Formatted {path}")
			changed = True
	return 0 if changed else 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
