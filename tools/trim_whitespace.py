#!/usr/bin/env python3
"""Remove trailing whitespace + trailing blank lines from all Lua files."""
import os
import sys
import argparse

def iter_lua_files(paths):
    if paths:
        for path in paths:
            path = os.path.abspath(path)

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


def trim_file(path: str) -> bool:
    with open(path, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()

    trimmed = [line.rstrip() for line in lines]

    while trimmed and trimmed[-1] == "":
        trimmed.pop()

    if trimmed == lines:
        return False

    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(trimmed))
        f.write("\n")

    return True


def main(argv):
    parser = argparse.ArgumentParser(description="Trim whitespace from Lua files.")
    parser.add_argument("paths", nargs="*", help="Files or directories to trim")
    args = parser.parse_args(argv)

    changed = False

    for lua_file in iter_lua_files(args.paths):
        if trim_file(lua_file):
            print(f"Trimmed {lua_file}")
            changed = True

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
