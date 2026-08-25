#!/usr/bin/env python3
"""Transcribe src/data/defaultMonsters.ts into an OCaml data module.

The output is a *dumb transcription*: every field arrives as the wire type
(`int option`, `string option`, `(string * int option) list`) with no
interpretation whatsoever, so it can be diffed against the TypeScript line by
line. All judgement -- the Defense reconciliation, the armour parse, the
attribute keys, the damage-die estimate -- lives in the hand-written, reviewed
`Monster_preset.of_raw`, which is where a reader will look for it.

Usage, from the repo root:

    python3 scripts/gen_monster_presets.py
    ./scripts/dune.sh build @fmt --auto-promote

The second step is not optional: this script does not attempt to match
ocamlformat, it only produces something ocamlformat can accept.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "data" / "defaultMonsters.ts"
OUT = ROOT / "lib" / "symbaroum" / "monster_presets_data.ml"

ATTRIBUTE_KEYS = ["acc", "cun", "dis", "per", "qui", "res", "str", "vig"]


def ocaml_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def opt_int(v):
    if v is None:
        return "None"
    return f"Some ({v})" if v < 0 else f"Some {v}"


def opt_string(v):
    return "None" if v is None else f"Some {ocaml_string(v)}"


def parse():
    text = SRC.read_text(encoding="utf-8")
    body = text.split("DEFAULT_MONSTERS: MonsterPreset[] = [", 1)[1]
    objects = re.findall(r"\{\s*\n\s*name:.*?\n  \},", body, re.S)
    presets = []
    for obj in objects:

        def field(key):
            m = re.search(r"\b" + key + r":\s*(.+?),\s*\n", obj)
            if m is None:
                raise SystemExit(f"missing field {key} in:\n{obj}")
            return m.group(1).strip()

        def quoted(key):
            v = field(key)
            m = re.fullmatch(r"'(.*)'", v) or re.fullmatch(r'"(.*)"', v)
            if m is None:
                raise SystemExit(f"field {key} is not a quoted string: {v}")
            return m.group(1)

        def nullable_int(key):
            v = field(key)
            return None if v == "null" else int(v)

        def nullable_string(key):
            v = field(key)
            if v == "null":
                return None
            m = re.fullmatch(r"'(.*)'", v) or re.fullmatch(r'"(.*)"', v)
            if m is None:
                raise SystemExit(f"field {key} is neither null nor quoted: {v}")
            return m.group(1)

        attrs_src = re.search(r"attributes:\s*\{(.*?)\}", obj, re.S).group(1)
        attrs = {
            k: (None if v == "null" else int(v))
            for k, v in re.findall(r"(\w+):\s*(null|-?\d+)", attrs_src)
        }
        unknown = set(attrs) - set(ATTRIBUTE_KEYS)
        if unknown:
            raise SystemExit(f"unknown attribute keys {unknown} in {obj}")

        presets.append(
            {
                "name": quoted("name"),
                "category": quoted("category"),
                "resistance": quoted("resistance"),
                "toughness": nullable_int("toughness"),
                "defense": nullable_int("defense"),
                "armor": nullable_string("armor"),
                "pain_threshold": nullable_int("painThreshold"),
                "attributes": [(k, attrs.get(k)) for k in ATTRIBUTE_KEYS],
            }
        )
    return presets


def render(presets):
    out = []
    out.append("(* GENERATED FILE -- DO NOT EDIT BY HAND.")
    out.append("")
    out.append(
        "   Transcribed from [src/data/defaultMonsters.ts] by"
    )
    out.append("   [scripts/gen_monster_presets.py]. Regenerate with:")
    out.append("")
    out.append("   {v")
    out.append("     python3 scripts/gen_monster_presets.py")
    out.append("     ./scripts/dune.sh build @fmt --auto-promote")
    out.append("   v}")
    out.append("")
    out.append(
        "   Deliberately uninterpreted: every field here is the wire type, so this"
    )
    out.append(
        "   file can be diffed against the TypeScript line by line. The Defense"
    )
    out.append(
        "   reconciliation, the armour parse and the damage-die estimate all happen"
    )
    out.append("   in [Monster_preset.of_raw]. *)")
    out.append("")
    out.append(f"let raw : Monster_preset.Raw.t list =")
    for i, p in enumerate(presets):
        open_ = "  [ " if i == 0 else "  ; "
        out.append(f"{open_}{{ name = {ocaml_string(p['name'])}")
        out.append(f"    ; category = {ocaml_string(p['category'])}")
        out.append(f"    ; resistance = {ocaml_string(p['resistance'])}")
        out.append(f"    ; toughness = {opt_int(p['toughness'])}")
        out.append(f"    ; defense = {opt_int(p['defense'])}")
        out.append(f"    ; armor = {opt_string(p['armor'])}")
        out.append(f"    ; pain_threshold = {opt_int(p['pain_threshold'])}")
        pairs = "; ".join(
            f"{ocaml_string(k)}, {opt_int(v)}" for k, v in p["attributes"]
        )
        out.append(f"    ; attributes = [ {pairs} ]")
        out.append("    }")
    out.append("  ]")
    out.append(";;")
    out.append("")
    return "\n".join(out)


def main():
    presets = parse()
    print(f"parsed {len(presets)} presets", file=sys.stderr)
    nulls = {
        k: sum(1 for p in presets if p[k] is None)
        for k in ("toughness", "defense", "armor", "pain_threshold")
    }
    print(f"null counts: {nulls}", file=sys.stderr)
    OUT.write_text(render(presets), encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}", file=sys.stderr)


if __name__ == "__main__":
    main()
