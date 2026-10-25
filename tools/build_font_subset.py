"""Build the bundled UI font: Noto Sans TC, cut down to the glyphs the game uses.

Browsers give a Godot Web build no access to system fonts, so every Chinese
character must come from a font inside the game. The full Noto Sans TC is
12 MB; this keeps printable ASCII, common CJK punctuation and every character
that appears in the game's scripts, scenes and data (a few hundred KB).

Run after adding new text:

    pip install fonttools==4.60.1
    python tools/build_font_subset.py path/to/NotoSansTC[wght].ttf

`tests/test_runner.gd` fails if any text in the project is missing from the
bundled font, so a forgotten rebuild is caught in CI.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "fonts" / "NotoSansTC-EchoVillage.ttf"
SOURCES = ("scripts", "scenes", "data")
SUFFIXES = {".gd", ".tscn", ".json", ".tres"}
WEIGHT = 500
EXTRA = "".join(chr(c) for c in range(0x20, 0x7F)) + "　、。，．：；？！「」『』（）《》〈〉【】…—–·・‧／％＋－×÷←→↑↓●○■□▶◀✓★☆～"


def project_characters() -> set[str]:
    characters = set(EXTRA)
    for folder in SOURCES:
        for path in (ROOT / folder).rglob("*"):
            if path.suffix in SUFFIXES:
                characters.update(path.read_text(encoding="utf-8"))
    characters.update((ROOT / "project.godot").read_text(encoding="utf-8"))
    return {c for c in characters if ord(c) >= 0x20}


def build(source: Path) -> None:
    font = TTFont(source)
    if "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": WEIGHT})
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.drop_tables += ["DSIG"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(text="".join(sorted(project_characters())))
    subsetter.subset(font)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUTPUT)
    print(f"{OUTPUT.relative_to(ROOT)}: {len(font.getBestCmap())} glyphs, {OUTPUT.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", type=Path, help="NotoSansTC[wght].ttf from google/fonts (ofl/notosanstc)")
    build(parser.parse_args().source)
