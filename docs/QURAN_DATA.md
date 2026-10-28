# The Quran data: making and publishing the packs

The app downloads the Quran (page lines, words, translations) from packs you
publish once. The page fonts come straight from Quran Foundation, nothing to do.
Reading is offline after the download.

## What you need from QUL

From <https://qul.tarteel.ai/resources> (free login). Files you already have are
marked. The builder reads the **SQLite** layout and the **JSON** files directly.

| What | File | Have |
| --- | --- | --- |
| Mushaf layout, **1405 print (V1)** | `qpc-v1-15-lines.db` | yes |
| Glyph codes by word, **V1** | `qpc-v1-glyph-codes-wbw.json` | yes |
| Mushaf layout, **1421 print (V2)** | `qpc-v2-15-lines.db` | yes |
| Glyph codes by word, **V2** | `qpc-v2.json` | yes |
| Quran script by word (QPC Hafs) | `qpc-hafs-word-by-word.json` | yes |
| Quran script by ayah (QPC Hafs) | `qpc-hafs.json` | yes |
| Word by word translation, English | `english-wbw-translation.json` | yes |
| Saheeh International, **with footnote tags** | `en-sahih-international-with-footnote-tags.json` | yes |
| Pickthall | `quran-en-pickthall-simple.json` | yes |

The *simple* Saheeh file is not needed: the footnote one has the same text and
the footnotes besides.

Each print needs **its own** glyph codes: V1 and V2 use different glyph codes for
every word (the page fonts of one print would show wrong letters with the codes
of the other). The builder pairs each layout with the glyph file you give it.

## Build the packs

Python 3 is needed (nothing to install with pip). From the project folder:

```
python tool/build_quran_packs.py ^
  --layout "v1|C:/qul/qpc-v1-15-lines.db|C:/qul/qpc-v1-glyph-codes-wbw.json" ^
  --layout "v2|C:/qul/qpc-v2-15-lines.db|C:/qul/qpc-v2.json" ^
  --word-script C:/qul/qpc-hafs-word-by-word.json ^
  --ayah-script C:/qul/qpc-hafs.json ^
  --word-translation C:/qul/english-wbw-translation.json ^
  --translation "sahih|Saheeh International|Saheeh International|en|C:/qul/en-sahih-international-with-footnote-tags.json" ^
  --translation "pickthall|Pickthall|Muhammad Marmaduke Pickthall|en|C:/qul/quran-en-pickthall-simple.json" ^
  --out dist
```

(`^` continues a line in Windows `cmd`; use `\` on Linux and macOS.) Leave out a
`--layout` line to build only one print.

The tool first checks the data against the app's page tables
(`lib/domain/reference/s_table.dart`) and that the pages cover all 6,236 ayahs.
**V1 must agree exactly** (it does with the files above). V2 is a different
print, so it is allowed to differ; the tool says where (it ends six surahs a
page later: 80, 84, 88, 90, 94, 96). If it stops with an error, nothing is
written.

It writes into `dist/`: `layout-v1.jsonl.gz`, `layout-v2.jsonl.gz`,
`words-en.jsonl.gz`, `translation-sahih.jsonl.gz`,
`translation-pickthall.jsonl.gz` and `manifest.json` (about 1.8 MB in all).

Its tests: `python -m unittest discover -s tool -p "test_*.py"`.

## Publish them

On GitHub, in your repository: *Releases > Draft a new release*, tag it for
example `quran-data-v1`, attach **all the files of `dist/`**, publish. The
address of the manifest is then:

```
https://github.com/YOUR-NAME/YOUR-REPO/releases/download/quran-data-v1/manifest.json
```

(The packs are data made from QUL's; in a public repository that is sharing
them. Check each resource's license first. Saheeh International and its
footnotes are the copyrighted work of its publisher; Pickthall is old enough to
be in the public domain.)

## Give the app the address

Either put it in `lib/quran_data/quran_data_config.dart`
(`defaultManifestUrl`), or open the app, **Settings > Quran data**, paste it in
*Where the packs are* and tap *Save and check*. Choose the mushaf print (the page fonts of the print you choose are downloaded, not both), then tap
*Download* on each part you want: the page lines, the page fonts, the Arabic
text font, the words and the translations.

## Which print?

The app opens on the **1405 print (V1)**. It is the classic Madinah print and the
one the app's page tables are made for: every surah starts and ends on the page
the planner expects. The **1421 print (V2)** has 36 pages with different ayahs
(120-123, 144-145, 531-534, 564-565, 567-570, 575-576 and 583-600), so a page
number can mean other ayahs than in the planner's tables. Use V2 only if that is
the book you read from.

## When something changes

- **A translation added**: build again with one more `--translation`, add the
  new file to the release. The app shows it in the list.
- **A pack corrected**: replace its file in the release. In the app, delete the
  part and download it again.
- **The format changes**: the manifest has a `version`; the app refuses a
  version it does not know, with a message.
