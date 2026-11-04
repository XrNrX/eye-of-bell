"""Regenerate all art in one go:   python tools/art/build_all.py

Steps, in order:
  1. Every tools/art/gen_*.py (the palette-bound generators). Each has build() and
     returns the files it wrote. They save through artio.save_png, which refuses
     any colour that isn't in palette.json.
  2. The older generators in LEGACY below. They still use their own colours and are
     not palette-checked yet; port them to this toolkit one at a time.
  3. Patch the Godot .import files under art/ so everything stays crisp.

Options:  --only NAME   run just the generator/legacy step with that name
          --skip-legacy
"""
import argparse
import importlib
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from palette import PROJECT_ROOT  # noqa: E402
from artio import patch_imports  # noqa: E402

# (name, script relative to the project root). Remove an entry once it is ported.
LEGACY = [
    ("tiles_and_sprites", "tools/make_textures.py"),
    ("skeleton", "tools/make_skeleton.py"),
]


def main():
    ap = argparse.ArgumentParser(description="Regenerate all art.")
    ap.add_argument("--only", help="run only the step with this name")
    ap.add_argument("--skip-legacy", action="store_true")
    args = ap.parse_args()

    failures = []
    start = time.time()

    for path in sorted(HERE.glob("gen_*.py")):
        name = path.stem[len("gen_"):]
        if args.only and args.only != name:
            continue
        print(f"[palette] {name}")
        try:
            written = importlib.import_module(path.stem).build()
            for f in written:
                print(f"    wrote {Path(f).relative_to(PROJECT_ROOT)}")
        except Exception as e:  # Keep going so one bad generator doesn't hide the rest.
            failures.append(name)
            print(f"    FAILED: {e}")

    if not args.skip_legacy:
        for name, script in LEGACY:
            if args.only and args.only != name:
                continue
            print(f"[legacy, not palette-checked] {name}")
            result = subprocess.run([sys.executable, str(PROJECT_ROOT / script)],
                                    cwd=PROJECT_ROOT, capture_output=True, text=True)
            for line in (result.stdout + result.stderr).strip().splitlines():
                print("    " + line)
            if result.returncode != 0:
                failures.append(name)

    changed = patch_imports()
    print(f"[imports] {len(changed)} .import file(s) updated")
    print(f"Done in {time.time() - start:.1f}s" + (f"; FAILED: {', '.join(failures)}" if failures else ""))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
