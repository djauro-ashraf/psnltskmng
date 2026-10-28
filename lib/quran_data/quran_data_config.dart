/// Where the app finds the packs it downloads.
abstract final class QuranDataConfig {
  /// The address of `manifest.json`, the list `tool/build_quran_packs.py`
  /// writes next to the packs. Put the address of your own release here (for
  /// example `https://github.com/NAME/REPO/releases/download/quran-data-v1/manifest.json`).
  /// While it is empty the reader types an address in Quran data; the one he
  /// types is kept and used instead.
  static const String defaultManifestUrl =
      'https://github.com/djauro-ashraf/psnltskmng/releases/download/quran-data-v1/manifest.json';
}
