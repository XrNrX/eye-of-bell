"""Regenerate all art in one go:   python tools/art/build_all.py

Steps, in order:
  1. Every tools/art/gen_*.py. Each has build() and
     returns the files it wrote. They save through artio.save_png, which refuses
     any colour that isn't in palette.json.
  2. Patch the Godot .import files under art/ so everything stays crisp.

Current generators: tiles (wall, floor, ceiling, door, ...), sprites (torch, key,
lever), ui (hand icon), items (item icons), skeleton, slime, portraits (party faces), swatch.
To add one, drop a gen_<name>.py with build() into this folder.

Options:  --only NAME   run just the generator with that name (e.g. --only tiles)
"""
import argparse
import importlib
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from palette import PROJECT_ROOT  # noqa: E402
from artio import patch_imports  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description="Regenerate all art.")
    ap.add_argument("--only", help="run only the step with this name")
    args = ap.parse_args()

    failures = []
    start = time.time()

    for path in sorted(HERE.glob("gen_*.py")):
        name = path.stem[len("gen_"):]
        if args.only and args.only != name:
            continue
        print(f"{name}")
        try:
            written = importlib.import_module(path.stem).build()
            for f in written:
                print(f"    wrote {Path(f).relative_to(PROJECT_ROOT)}")
        except Exception as e:  # Keep going so one bad generator doesn't hide the rest.
            failures.append(name)
            print(f"    FAILED: {e}")

    changed = patch_imports()
    print(f"[imports] {len(changed)} .import file(s) updated")
    print(f"Done in {time.time() - start:.1f}s" + (f"; FAILED: {', '.join(failures)}" if failures else ""))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
