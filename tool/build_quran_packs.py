#!/usr/bin/env python3
"""Builds the Quran packs the app downloads, from QUL downloads.

Python 3, standard library only. Run from the project folder:

    python tool/build_quran_packs.py ^
      --layout "v1|C:/qul/qpc-v1-15-lines.db|C:/qul/qpc-v1-glyph-codes-wbw.json" ^
      --layout "v2|C:/qul/qpc-v2-15-lines.db|C:/qul/qpc-v2-glyph-codes-wbw.json" ^
      --word-script C:/qul/qpc-hafs-word-by-word.json ^
      --ayah-script C:/qul/qpc-hafs.json ^
      --word-translation C:/qul/english-wbw-translation.json ^
      --translation "sahih|Saheeh International|Saheeh International|en|C:/qul/sahih-footnotes.json" ^
      --translation "pickthall|Pickthall|M. M. Pickthall|en|C:/qul/pickthall.json" ^
      --out dist

(`^` continues a line in Windows cmd; use `\\` on Linux and macOS.)

--layout can be given once per mushaf edition: "edition|layout database|glyph
codes". The layout database is the SQLite download of a QUL "mushaf layout"
(`pages` table). The glyph codes are the QUL "glyph codes by word" JSON of the
same edition (V1 glyphs for the V1 layout, V2 glyphs for the V2 layout).

Writes into --out: layout-<edition>.jsonl.gz for each --layout, words-en.jsonl.gz,
translation-<id>.jsonl.gz for each --translation, and manifest.json. Upload them
all to one place (a GitHub release) and give the app the address of
manifest.json. See docs/QURAN_DATA.md.

Before writing anything it checks the data against the app's own page tables
(`lib/domain/reference/s_table.dart`): the classic V1 print must agree exactly;
V2 is allowed to differ (it is a different print) and says where.
Exits with 1 on any problem.
"""
import argparse
import gzip
import json
import re
import sqlite3
import sys
from pathlib import Path

PAGES = 604
SURAHS = 114
VERSES = 6236

# The end-of-ayah mark is a word of the export (the ayah number in a circle),
# but it is not a word to translate.
END_MARK = re.compile(r"^[\s\u06DD\u0660-\u0669\u06F0-\u06F9]+$")
# The ayah script ends every ayah with its number.
TRAILING_NUMBER = re.compile(r"\s*[\u0660-\u0669\u06F0-\u06F9]+\s*$")
# Markup in a translation: every tag but the footnote marker is removed.
OTHER_TAGS = re.compile(r"<(?!/?sup\b)[^>]*>")
ANY_TAG = re.compile(r"<[^>]*>")
SPACES = re.compile(r"\s+")
EDITIONS = ("v1", "v2")


class BuildError(Exception):
    pass


def read_json(path):
    path = Path(path)
    if not path.is_file():
        raise BuildError(f"File not found: {path}")
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise BuildError(f"{path} is not a JSON object")
    return data


def is_end_mark(text):
    return bool(END_MARK.match(text))


def clean_translation(text):
    """The text of a translation with only the footnote markers kept."""
    return SPACES.sub(" ", OTHER_TAGS.sub("", text)).strip()


def clean_footnote(text):
    return SPACES.sub(" ", ANY_TAG.sub(" ", text)).strip()


def strip_ayah_number(text):
    return TRAILING_NUMBER.sub("", text).strip()


class WordIndex:
    """The words of the Quran by number, from a QUL "Quran script by word"
    export: {"1:1:1": {"id": 1, "location": "1:1:1", "text": "..."}, ...}."""

    def __init__(self, word_script):
        self.key_by_id = {}
        self.text_by_id = {}
        by_key = {}
        for name, value in word_script.items():
            if not isinstance(value, dict):
                raise BuildError(f"Word {name} is not an object")
            word_id, text = value.get("id"), value.get("text")
            location = str(value.get("location") or name)
            parts = location.split(":")
            if not isinstance(word_id, int) or not isinstance(text, str) or len(parts) != 3:
                raise BuildError(f"Word {name} is badly formed")
            key = f"{parts[0]}:{parts[1]}"
            self.key_by_id[word_id] = key
            self.text_by_id[word_id] = text
            by_key.setdefault(key, []).append((int(parts[2]), location, text))
        self.words_by_key = {
            key: [(text, location) for _, location, text in sorted(items)]
            for key, items in by_key.items()
        }
        self.ayah_count = {}
        for key in self.words_by_key:
            s, a = (int(x) for x in key.split(":"))
            self.ayah_count[s] = max(self.ayah_count.get(s, 0), a)

    def verse_count(self):
        return len(self.words_by_key)


def read_layout_rows(db_path):
    """The rows of the `pages` table of a QUL layout database, by page."""
    path = Path(db_path)
    if not path.is_file():
        raise BuildError(f"File not found: {path}")
    connection = sqlite3.connect(str(path))
    try:
        rows = connection.execute(
            "select page_number, line_number, line_type, is_centered, "
            "first_word_id, last_word_id, surah_number from pages "
            "order by page_number, line_number"
        ).fetchall()
    except sqlite3.Error as error:
        raise BuildError(f"{path} is not a QUL layout database ({error})")
    finally:
        connection.close()
    pages = {}
    for row in rows:
        pages.setdefault(int(row[0]), []).append(row)
    return pages


def to_int(value):
    """The databases keep an empty text where a number is missing."""
    if value is None or value == "":
        return None
    return int(value)


def build_layout_pages(rows_by_page, glyph_by_id, index, page_count=PAGES):
    """The page objects of a layout pack: the QUL page export (lines with their
    type, alignment, word numbers and glyph codes), plus the ayahs ("verses")
    that have a word on the page, in order.

    An ayah line also gets "ends": for each end-of-ayah mark in it, its place in
    "data" and its Unicode text (the ayah number). Quran Foundation asks for the
    end marks to be drawn with the Unicode font, not with the page font."""
    pages = {}
    for page in range(1, page_count + 1):
        rows = rows_by_page.get(page)
        if not rows:
            raise BuildError(f"The layout has no page {page}")
        lines, verses, seen = {}, [], set()
        expected = 1
        for _, number, line_type, centered, first, last, surah in rows:
            if int(number) != expected:
                raise BuildError(f"Page {page}: line {number} where {expected} was expected")
            expected += 1
            line = {"type": line_type, "alignment": "centered" if centered else "justified"}
            if line_type == "ayah":
                first, last = to_int(first), to_int(last)
                if first is None or last is None or last < first:
                    raise BuildError(f"Page {page}, line {number}: bad word numbers")
                try:
                    data = [glyph_by_id[i] for i in range(first, last + 1)]
                except KeyError as error:
                    raise BuildError(f"Page {page}, line {number}: no glyph for word {error}")
                line.update(first_word_id=first, last_word_id=last, data=data)
                ends = {
                    str(place): index.text_by_id[word_id]
                    for place, word_id in enumerate(range(first, last + 1))
                    if word_id in index.text_by_id and is_end_mark(index.text_by_id[word_id])
                }
                if ends:
                    line["ends"] = ends
                for word_id in range(first, last + 1):
                    key = index.key_by_id.get(word_id)
                    if key is None:
                        raise BuildError(f"Page {page}: word {word_id} is not in the word script")
                    if key not in seen:
                        seen.add(key)
                        verses.append(key)
            elif line_type == "surah_name":
                surah = to_int(surah)
                if surah is None:
                    raise BuildError(f"Page {page}, line {number}: a banner without an s")
                line["surah_number"] = surah
            elif line_type != "basmallah":
                raise BuildError(f"Page {page}, line {number}: unknown type {line_type}")
            lines[str(number)] = line
        pages[page] = {"page": page, "lines": lines, "verses": verses}
    return pages


def layout_lines(pages):
    return [json.dumps(pages[p], ensure_ascii=False, separators=(",", ":")) for p in sorted(pages)]


def words_lines(index, ayah_script, word_translation, surah_count=SURAHS):
    """The words pack: for each s, its ayahs with the whole Arabic text and the
    Arabic and English of each word (the end mark is not a word)."""
    out = []
    for s in range(1, surah_count + 1):
        count = index.ayah_count.get(s)
        if not count:
            raise BuildError(f"The word script has no s {s}")
        ayahs = []
        for n in range(1, count + 1):
            key = f"{s}:{n}"
            words = index.words_by_key.get(key)
            if not words:
                raise BuildError(f"The word script has no ayah {key}")
            script = ayah_script.get(key)
            text = script.get("text") if isinstance(script, dict) else None
            if not isinstance(text, str) or not text.strip():
                text = " ".join(t for t, _ in words if not is_end_mark(t))
            ayahs.append(
                {
                    "t": strip_ayah_number(text),
                    "w": [
                        [t, clean_translation(str(word_translation.get(loc, "")))]
                        for t, loc in words
                        if not is_end_mark(t)
                    ],
                }
            )
        out.append(json.dumps({"s": s, "a": ayahs}, ensure_ascii=False, separators=(",", ":")))
    return out


def translation_lines(index, translation, surah_count=SURAHS):
    """A translation pack: for each s, one entry per ayah with its text (the
    footnote markers `<sup foot_note="ID">1</sup>` kept) and its footnotes."""
    out = []
    for s in range(1, surah_count + 1):
        entries = []
        for n in range(1, index.ayah_count[s] + 1):
            key = f"{s}:{n}"
            item = translation.get(key)
            if not isinstance(item, dict) or not isinstance(item.get("t"), str):
                raise BuildError(f"The translation has no text for {key}")
            entry = {"x": clean_translation(item["t"])}
            footnotes = item.get("f")
            if isinstance(footnotes, dict):
                # A footnote with no text (QUL has one, at 7:143) is left out: its
                # marker is then only printed, there is nothing to open.
                kept = {str(i): clean_footnote(str(t)) for i, t in footnotes.items()}
                kept = {i: t for i, t in kept.items() if t}
                if kept:
                    entry["f"] = kept
            entries.append(entry)
        out.append(json.dumps({"s": s, "t": entries}, ensure_ascii=False, separators=(",", ":")))
    return out


# --- Checks -----------------------------------------------------------------

def read_s_table(project_root):
    """The first and last page of each s the app knows (STable)."""
    path = Path(project_root) / "lib" / "domain" / "reference" / "s_table.dart"
    if not path.is_file():
        raise BuildError(f"Cannot find {path}; run this from the project folder")
    pairs = [(int(a), int(b)) for a, b in re.findall(r"_S\((\d+),\s*(\d+)\)", path.read_text(encoding="utf-8"))]
    if len(pairs) != SURAHS:
        raise BuildError(f"Read {len(pairs)} rows of the s table, {SURAHS} expected")
    return pairs


def surah_pages(pages, index):
    """The first and last page of each s, found from the words on the pages."""
    first, last = {}, {}
    for page_number, page in pages.items():
        for line in page["lines"].values():
            if line["type"] != "ayah":
                continue
            for word_id in range(line["first_word_id"], line["last_word_id"] + 1):
                s = int(index.key_by_id[word_id].split(":")[0])
                first[s] = min(first.get(s, page_number), page_number)
                last[s] = max(last.get(s, page_number), page_number)
    return first, last


def check_layout(edition, pages, index, s_table):
    """Returns (errors, warnings) for one edition."""
    errors, warnings = [], []
    covered = set()
    for page in pages.values():
        covered.update(page["verses"])
    if len(covered) != VERSES or len(covered) != index.verse_count():
        errors.append(
            f"{edition}: the pages cover {len(covered)} ayahs, the word script has "
            f"{index.verse_count()}; both must be {VERSES}. Is the word script of the same mushaf?"
        )
    first, last = surah_pages(pages, index)
    diffs = [
        f"s {s}: pages {first.get(s)}-{last.get(s)}, the s table says {a}-{b}"
        for s, (a, b) in enumerate(s_table, start=1)
        if (first.get(s), last.get(s)) != (a, b)
    ]
    if diffs:
        text = f"{edition} differs from the app's s table on {len(diffs)} s: " + "; ".join(diffs[:8])
        # The classic print is the one the tables were made for.
        (errors if edition == "v1" else warnings).append(text)
    banners = sum(1 for p in pages.values() for l in p["lines"].values() if l["type"] == "surah_name")
    if banners != SURAHS:
        errors.append(f"{edition}: {banners} banners, {SURAHS} expected")
    return errors, warnings


def verify_output(out_dir, expected_packs):
    """Reads every file back the way the app does."""
    problems = []
    for pack_id, kind in expected_packs:
        path = Path(out_dir) / f"{pack_id}.jsonl.gz"
        lines = gzip.decompress(path.read_bytes()).decode("utf-8").split("\n")
        want, key = (PAGES, "page") if kind == "layout" else (SURAHS, "s")
        if len(lines) != want:
            problems.append(f"{pack_id}: {len(lines)} lines, {want} expected")
            continue
        for number, line in enumerate(lines, start=1):
            obj = json.loads(line)
            if obj.get(key) != number:
                problems.append(f"{pack_id}: line {number} is not {key} {number}")
                break
    return problems


def write_pack(out_dir, pack_id, kind, lines, extra):
    data = gzip.compress("\n".join(lines).encode("utf-8"), compresslevel=9, mtime=0)
    (Path(out_dir) / f"{pack_id}.jsonl.gz").write_bytes(data)
    return {
        "id": pack_id,
        "kind": kind,
        **extra,
        "file": {"url": f"{pack_id}.jsonl.gz", "bytes": len(data)},
    }


def parse_spec(spec, parts, what):
    pieces = spec.split("|")
    if len(pieces) != parts:
        raise BuildError(f'{what} needs {parts} parts separated by "|", got: {spec}')
    return pieces


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--layout", action="append", required=True)
    parser.add_argument("--word-script", required=True)
    parser.add_argument("--ayah-script", required=True)
    parser.add_argument("--word-translation", required=True)
    parser.add_argument("--translation", action="append", default=[])
    parser.add_argument("--out", default="dist")
    parser.add_argument("--project", default=".", help="the project folder (for lib/domain/reference/s_table.dart)")
    args = parser.parse_args(argv)

    try:
        s_table = read_s_table(args.project)
        index = WordIndex(read_json(args.word_script))
        print(f"Word script: {len(index.key_by_id)} words, {index.verse_count()} ayahs")
        ayah_script = read_json(args.ayah_script)
        word_translation = read_json(args.word_translation)

        built, warnings = [], []
        for spec in args.layout:
            edition, db, glyphs = parse_spec(spec, 3, "--layout")
            if edition not in EDITIONS:
                raise BuildError(f"Unknown edition {edition}; use one of {', '.join(EDITIONS)}")
            glyph_by_id = {}
            for value in read_json(glyphs).values():
                glyph_by_id[value["id"]] = value["text"]
            pages = build_layout_pages(read_layout_rows(db), glyph_by_id, index)
            errors, notes = check_layout(edition, pages, index, s_table)
            if errors:
                raise BuildError("\n  - ".join([f"The {edition} layout does not fit the app:"] + errors))
            warnings += notes
            built.append((f"layout-{edition}", "layout", layout_lines(pages), {}))
            print(f"Layout {edition}: {PAGES} pages")

        built.append(
            (
                "words-en",
                "words",
                words_lines(index, ayah_script, word_translation),
                {"title": "Words and Arabic text", "description": "Every ayah with the English of each word."},
            )
        )
        for spec in args.translation:
            tid, title, author, language, path = parse_spec(spec, 5, "--translation")
            if not re.fullmatch(r"[a-z0-9]+", tid):
                raise BuildError(f"Bad translation id: {tid}")
            built.append(
                (
                    f"translation-{tid}",
                    "translation",
                    translation_lines(index, read_json(path)),
                    {"title": title, "author": author, "language": language},
                )
            )

        titles = {
            "layout-v1": ("Quran page lines, 1405 print (V1)", "The lines of the 604 pages of the classic Madinah print."),
            "layout-v2": ("Quran page lines, 1421 print (V2)", "The lines of the 604 pages of the newer Madinah print."),
        }
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        manifest = []
        for pack_id, kind, lines, extra in built:
            if pack_id in titles:
                extra = {"title": titles[pack_id][0], "description": titles[pack_id][1]}
            manifest.append(write_pack(out, pack_id, kind, lines, extra))
            print(f"  {pack_id}.jsonl.gz  {manifest[-1]['file']['bytes'] / 1024:.0f} KB")

        problems = verify_output(out, [(m["id"], m["kind"]) for m in manifest])
        if problems:
            raise BuildError("The written packs do not read back:\n  - " + "\n  - ".join(problems))
        (out / "manifest.json").write_text(
            json.dumps({"version": 1, "packs": manifest}, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        for note in warnings:
            print("Note:", note)
        print(f"Done: {out / 'manifest.json'}")
        return 0
    except BuildError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
