/// How the reader shows the Quran. One choice, kept in the Quran preferences
/// (`quranViewProvider`), and the SAME one at the top of Browse (what a tap on
/// a row opens) and in the reader (the switch of its reading line):
///
/// - [mushaf]: the page as printed;
/// - [words]: the ayahs one after another, each with its Arabic, its words and
///   its translation;
/// - [details]: the same stream as [words], but each ayah shows only its word
///   by word and a Details dropdown (where it is, the state of its page), with
///   the Tafsir button; the banners of a surah, a juz, a ch and a page carry a
///   Details dropdown of their own (their state and their notes).
///
/// The values are kept by name: a value that is not here reads as the default.
enum QuranView { mushaf, words, details }
