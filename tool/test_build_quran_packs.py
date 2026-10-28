"""Tests of tool/build_quran_packs.py. Run from the project folder:

    python -m unittest discover -s tool -p "test_*.py"
"""
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import build_quran_packs as b  # noqa: E402


def word_script():
    """An invented Quran: s 1 has ayahs 1 and 2, s 2 has ayah 1. Every ayah has
    two words and its end mark."""
    items, word_id = {}, 0
    for s, a in [(1, 1), (1, 2), (2, 1)]:
        for w, text in enumerate([f"w{s}_{a}_1", f"w{s}_{a}_2", "\u0661"], start=1):
            word_id += 1
            loc = f"{s}:{a}:{w}"
            items[loc] = {"id": word_id, "location": loc, "text": text}
    return items


class Helpers(unittest.TestCase):
    def test_end_mark(self):
        self.assertTrue(b.is_end_mark("\u0661"))
        self.assertTrue(b.is_end_mark("\u06DD\u0662\u0663"))
        self.assertFalse(b.is_end_mark("بِسۡمِ"))
        self.assertFalse(b.is_end_mark("w1"))

    def test_translation_keeps_only_footnote_markers(self):
        text = 'Text<sup foot_note="12">1</sup> <i>of</i>\n the <b>ayah</b>'
        self.assertEqual(b.clean_translation(text), 'Text<sup foot_note="12">1</sup> of the ayah')

    def test_footnote_loses_all_markup(self):
        self.assertEqual(b.clean_footnote("<p>A  note</p>\n<p>more</p>"), "A note more")

    def test_ayah_number_is_dropped(self):
        self.assertEqual(b.strip_ayah_number("بِسۡمِ ٱللَّهِ ١"), "بِسۡمِ ٱللَّهِ")
        self.assertEqual(b.strip_ayah_number("نص ١٢٣"), "نص")
        self.assertEqual(b.strip_ayah_number("نص"), "نص")


class Index(unittest.TestCase):
    def test_words_and_ayahs(self):
        index = b.WordIndex(word_script())
        self.assertEqual(index.key_by_id[1], "1:1")
        self.assertEqual(index.key_by_id[9], "2:1")
        self.assertEqual(index.ayah_count, {1: 2, 2: 1})
        self.assertEqual(index.verse_count(), 3)
        self.assertEqual([t for t, _ in index.words_by_key["1:2"]], ["w1_2_1", "w1_2_2", "\u0661"])

    def test_bad_script(self):
        with self.assertRaises(b.BuildError):
            b.WordIndex({"1:1:1": 5})
        with self.assertRaises(b.BuildError):
            b.WordIndex({"1:1:1": {"id": 1, "text": "a", "location": "1:1"}})


def layout_db(rows):
    path = Path(tempfile.mkdtemp()) / "layout.db"
    con = sqlite3.connect(path)
    con.execute(
        "create table pages (page_number integer, line_number integer, line_type text, "
        "is_centered integer, first_word_id integer, last_word_id integer, surah_number integer)"
    )
    con.executemany("insert into pages values (?,?,?,?,?,?,?)", rows)
    con.commit()
    con.close()
    return path


class Layout(unittest.TestCase):
    def setUp(self):
        self.index = b.WordIndex(word_script())
        self.glyphs = {i: f"g{i}" for i in range(1, 10)}
        # page 1: banner of s 1, then ayah 1 and the words of ayah 2 without its end mark;
        # page 2: the end mark of ayah 2, then s 2.
        self.rows = [
            (1, 1, "surah_name", 1, "", "", 1),
            (1, 2, "ayah", 0, 1, 3, ""),
            (1, 3, "ayah", 1, 4, 5, ""),
            (2, 1, "ayah", 1, 6, 6, ""),
            (2, 2, "surah_name", 1, "", "", 2),
            (2, 3, "basmallah", 1, "", "", ""),
            (2, 4, "ayah", 0, 7, 9, ""),
        ]

    def pages(self, rows=None):
        return b.build_layout_pages(b.read_layout_rows(layout_db(rows or self.rows)), self.glyphs, self.index, page_count=2)

    def test_lines_alignment_glyphs_and_verses(self):
        pages = self.pages()
        p1 = pages[1]
        self.assertEqual(p1["page"], 1)
        self.assertEqual(p1["lines"]["1"], {"type": "surah_name", "alignment": "centered", "surah_number": 1})
        self.assertEqual(
            p1["lines"]["2"],
            {
                "type": "ayah",
                "alignment": "justified",
                "first_word_id": 1,
                "last_word_id": 3,
                "data": ["g1", "g2", "g3"],
                # word 3 is the end mark of ayah 1:1: drawn with the Unicode font
                "ends": {"2": "\u0661"},
            },
        )
        self.assertEqual(p1["lines"]["3"]["alignment"], "centered")
        # A line with no end mark has no "ends" at all.
        self.assertNotIn("ends", p1["lines"]["3"] if p1["lines"]["3"]["type"] != "ayah" else {})
        # The ayah that runs over two pages is on both.
        self.assertEqual(p1["verses"], ["1:1", "1:2"])
        self.assertEqual(pages[2]["verses"], ["1:2", "2:1"])
        self.assertEqual(pages[2]["lines"]["3"], {"type": "basmallah", "alignment": "centered"})

    def test_end_marks_are_found_by_their_place_in_the_line(self):
        pages = self.pages()
        # page 1, line 3: words 4 and 5 are ayah 1:2's two words, no end mark
        self.assertNotIn("ends", pages[1]["lines"]["3"])
        # page 2, line 1: word 6 is the end mark of ayah 1:2, alone on its line
        self.assertEqual(pages[2]["lines"]["1"]["ends"], {"0": "\u0661"})
        # page 2, line 4: words 7-9 are ayah 2:1, its end mark last
        self.assertEqual(pages[2]["lines"]["4"]["ends"], {"2": "\u0661"})

    def test_a_banner_without_an_s_is_refused(self):
        rows = list(self.rows)
        rows[0] = (1, 1, "surah_name", 1, "", "", "")
        with self.assertRaises(b.BuildError):
            self.pages(rows)

    def test_missing_glyph_missing_page_and_gap_are_refused(self):
        del self.glyphs[2]
        with self.assertRaises(b.BuildError):
            self.pages()
        self.glyphs[2] = "g2"
        with self.assertRaises(b.BuildError):
            self.pages([r for r in self.rows if r[0] == 1])  # no page 2
        gap = [r if r[:2] != (1, 3) else (1, 4, *r[2:]) for r in self.rows]
        with self.assertRaises(b.BuildError):
            self.pages(gap)

    def test_the_lines_are_one_json_object_per_page(self):
        lines = b.layout_lines(self.pages())
        self.assertEqual([json.loads(l)["page"] for l in lines], [1, 2])


class Texts(unittest.TestCase):
    def setUp(self):
        self.index = b.WordIndex(word_script())

    def test_words_pack(self):
        ayah_script = {
            "1:1": {"text": "ayah one \u0661"},
            "1:2": {"text": "ayah two \u0662"},
            "2:1": {"text": "ayah three \u0661"},
        }
        gloss = {"1:1:1": "first", "1:1:2": "<b>second</b>"}
        lines = b.words_lines(self.index, ayah_script, gloss, surah_count=2)
        s1 = json.loads(lines[0])
        self.assertEqual(s1["s"], 1)
        self.assertEqual(len(s1["a"]), 2)
        self.assertEqual(s1["a"][0]["t"], "ayah one")
        self.assertEqual(s1["a"][0]["w"], [["w1_1_1", "first"], ["w1_1_2", "second"]])  # no end mark
        self.assertEqual(s1["a"][1]["w"][0], ["w1_2_1", ""])  # no English: empty, not missing
        self.assertEqual(json.loads(lines[1])["a"][0]["t"], "ayah three")

    def test_the_text_of_an_ayah_is_joined_from_its_words_when_missing(self):
        lines = b.words_lines(self.index, {}, {}, surah_count=2)
        self.assertEqual(json.loads(lines[1])["a"][0]["t"], "w2_1_1 w2_1_2")

    def test_translation_pack_keeps_markers_and_footnotes(self):
        translation = {
            "1:1": {"t": 'In the name<sup foot_note="9">1</sup>', "f": {"9": "<p>A note</p>"}},
            "1:2": {"t": "Praise", "f": {}},
            "2:1": {"t": "Alif"},
        }
        lines = b.translation_lines(self.index, translation, surah_count=2)
        s1 = json.loads(lines[0])
        self.assertEqual(s1["t"][0], {"x": 'In the name<sup foot_note="9">1</sup>', "f": {"9": "A note"}})
        self.assertEqual(s1["t"][1], {"x": "Praise"})  # an empty footnote list is left out
        self.assertEqual(json.loads(lines[1])["t"], [{"x": "Alif"}])

    def test_an_empty_footnote_is_left_out(self):
        translation = {
            "1:1": {"t": 'A<sup foot_note="1">1</sup>B<sup foot_note="2">2</sup>', "f": {"1": "  ", "2": "<p>Kept</p>"}},
            "1:2": {"t": 'C<sup foot_note="3">1</sup>', "f": {"3": ""}},
            "2:1": {"t": "D"},
        }
        s1 = json.loads(b.translation_lines(self.index, translation, surah_count=2)[0])
        self.assertEqual(s1["t"][0]["f"], {"2": "Kept"})
        self.assertNotIn("f", s1["t"][1])  # nothing left: no "f" at all

    def test_a_translation_missing_an_ayah_is_refused(self):
        with self.assertRaises(b.BuildError):
            b.translation_lines(self.index, {"1:1": {"t": "x"}}, surah_count=2)


class Spec(unittest.TestCase):
    def test_parse_spec(self):
        self.assertEqual(b.parse_spec("a|b|c", 3, "x"), ["a", "b", "c"])
        with self.assertRaises(b.BuildError):
            b.parse_spec("a|b", 3, "x")


if __name__ == "__main__":
    unittest.main()
