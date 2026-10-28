/// One s with its names. Display data only: nothing in the rules, the
/// planners or the AI reads it (checked in `test/domain/surah_names_test.dart`).
///
/// "s" is used exactly as written everywhere else in the app; this is the
/// only place that knows what an s is called.
final class SurahName {
  const SurahName(this.number, this.arabic, this.transliteration, this.meaning);

  /// The s number (1 to [SurahNames.count]), as in `STable`.
  final int number;

  /// The Arabic name, as printed in the mushaf, without the vowel marks
  /// ("الفاتحة"). Right to left: draw it with `TextDirection.rtl`.
  final String arabic;

  /// The English (Latin letters) name ("Al-Fatihah"). ‘ stands for the
  /// letter ayn and ’ for the hamza.
  final String transliteration;

  /// What the name means in English ("The Opening"). Some names are only a
  /// letter or a person; those repeat the name.
  final String meaning;
}

/// The Arabic and English names of the 114 s, in s order (the s of `STable`).
///
/// Const data with read-only lookups, like the other reference tables. Pure
/// Dart. An s outside 1 to [count] throws a [RangeError].
abstract final class SurahNames {
  /// The number of s (114).
  static const int count = 114;

  /// The names of [s] (1 to [count]).
  static SurahName of(int s) {
    RangeError.checkValueInInterval(s, 1, count, 's');
    return _rows[s - 1];
  }

  /// All of them, in s order (unmodifiable).
  static List<SurahName> get all => _rows;

  static const List<SurahName> _rows = [
    SurahName(1, 'الفاتحة', 'Al-Fatihah', 'The Opening'),
    SurahName(2, 'البقرة', 'Al-Baqarah', 'The Cow'),
    SurahName(3, 'آل عمران', 'Ali ‘Imran', 'Family of Imran'),
    SurahName(4, 'النساء', 'An-Nisa’', 'The Women'),
    SurahName(5, 'المائدة', 'Al-Ma’idah', 'The Table Spread'),
    SurahName(6, 'الأنعام', 'Al-An‘am', 'The Cattle'),
    SurahName(7, 'الأعراف', 'Al-A‘raf', 'The Heights'),
    SurahName(8, 'الأنفال', 'Al-Anfal', 'The Spoils of War'),
    SurahName(9, 'التوبة', 'At-Tawbah', 'The Repentance'),
    SurahName(10, 'يونس', 'Yunus', 'Jonah'),
    SurahName(11, 'هود', 'Hud', 'Hud'),
    SurahName(12, 'يوسف', 'Yusuf', 'Joseph'),
    SurahName(13, 'الرعد', 'Ar-Ra‘d', 'The Thunder'),
    SurahName(14, 'إبراهيم', 'Ibrahim', 'Abraham'),
    SurahName(15, 'الحجر', 'Al-Hijr', 'The Rocky Tract'),
    SurahName(16, 'النحل', 'An-Nahl', 'The Bee'),
    SurahName(17, 'الإسراء', 'Al-Isra’', 'The Night Journey'),
    SurahName(18, 'الكهف', 'Al-Kahf', 'The Cave'),
    SurahName(19, 'مريم', 'Maryam', 'Mary'),
    SurahName(20, 'طه', 'Ta-Ha', 'Ta-Ha'),
    SurahName(21, 'الأنبياء', 'Al-Anbiya’', 'The Prophets'),
    SurahName(22, 'الحج', 'Al-Hajj', 'The Pilgrimage'),
    SurahName(23, 'المؤمنون', 'Al-Mu’minun', 'The Believers'),
    SurahName(24, 'النور', 'An-Nur', 'The Light'),
    SurahName(25, 'الفرقان', 'Al-Furqan', 'The Criterion'),
    SurahName(26, 'الشعراء', 'Ash-Shu‘ara’', 'The Poets'),
    SurahName(27, 'النمل', 'An-Naml', 'The Ant'),
    SurahName(28, 'القصص', 'Al-Qasas', 'The Stories'),
    SurahName(29, 'العنكبوت', 'Al-‘Ankabut', 'The Spider'),
    SurahName(30, 'الروم', 'Ar-Rum', 'The Romans'),
    SurahName(31, 'لقمان', 'Luqman', 'Luqman'),
    SurahName(32, 'السجدة', 'As-Sajdah', 'The Prostration'),
    SurahName(33, 'الأحزاب', 'Al-Ahzab', 'The Combined Forces'),
    SurahName(34, 'سبأ', 'Saba’', 'Sheba'),
    SurahName(35, 'فاطر', 'Fatir', 'Originator'),
    SurahName(36, 'يس', 'Ya-Sin', 'Ya Sin'),
    SurahName(37, 'الصافات', 'As-Saffat', 'Those who set the Ranks'),
    SurahName(38, 'ص', 'Sad', 'The Letter Sad'),
    SurahName(39, 'الزمر', 'Az-Zumar', 'The Troops'),
    SurahName(40, 'غافر', 'Ghafir', 'The Forgiver'),
    SurahName(41, 'فصلت', 'Fussilat', 'Explained in Detail'),
    SurahName(42, 'الشورى', 'Ash-Shura', 'The Consultation'),
    SurahName(43, 'الزخرف', 'Az-Zukhruf', 'The Ornaments of Gold'),
    SurahName(44, 'الدخان', 'Ad-Dukhan', 'The Smoke'),
    SurahName(45, 'الجاثية', 'Al-Jathiyah', 'The Crouching'),
    SurahName(46, 'الأحقاف', 'Al-Ahqaf', 'The Wind-Curved Sandhills'),
    SurahName(47, 'محمد', 'Muhammad', 'Muhammad'),
    SurahName(48, 'الفتح', 'Al-Fath', 'The Victory'),
    SurahName(49, 'الحجرات', 'Al-Hujurat', 'The Rooms'),
    SurahName(50, 'ق', 'Qaf', 'The Letter Qaf'),
    SurahName(51, 'الذاريات', 'Adh-Dhariyat', 'The Winnowing Winds'),
    SurahName(52, 'الطور', 'At-Tur', 'The Mount'),
    SurahName(53, 'النجم', 'An-Najm', 'The Star'),
    SurahName(54, 'القمر', 'Al-Qamar', 'The Moon'),
    SurahName(55, 'الرحمن', 'Ar-Rahman', 'The Beneficent'),
    SurahName(56, 'الواقعة', 'Al-Waqi‘ah', 'The Inevitable'),
    SurahName(57, 'الحديد', 'Al-Hadid', 'The Iron'),
    SurahName(58, 'المجادلة', 'Al-Mujadilah', 'The Pleading Woman'),
    SurahName(59, 'الحشر', 'Al-Hashr', 'The Exile'),
    SurahName(60, 'الممتحنة', 'Al-Mumtahanah', 'She that is to be examined'),
    SurahName(61, 'الصف', 'As-Saff', 'The Ranks'),
    SurahName(62, 'الجمعة', 'Al-Jumu‘ah', 'Friday'),
    SurahName(63, 'المنافقون', 'Al-Munafiqun', 'The Hypocrites'),
    SurahName(64, 'التغابن', 'At-Taghabun', 'Mutual Disillusion'),
    SurahName(65, 'الطلاق', 'At-Talaq', 'Divorce'),
    SurahName(66, 'التحريم', 'At-Tahrim', 'The Prohibition'),
    SurahName(67, 'الملك', 'Al-Mulk', 'The Sovereignty'),
    SurahName(68, 'القلم', 'Al-Qalam', 'The Pen'),
    SurahName(69, 'الحاقة', 'Al-Haqqah', 'The Reality'),
    SurahName(70, 'المعارج', 'Al-Ma‘arij', 'The Ascending Stairways'),
    SurahName(71, 'نوح', 'Nuh', 'Noah'),
    SurahName(72, 'الجن', 'Al-Jinn', 'The Jinn'),
    SurahName(73, 'المزمل', 'Al-Muzzammil', 'The Enshrouded One'),
    SurahName(74, 'المدثر', 'Al-Muddaththir', 'The Cloaked One'),
    SurahName(75, 'القيامة', 'Al-Qiyamah', 'The Resurrection'),
    SurahName(76, 'الإنسان', 'Al-Insan', 'The Human'),
    SurahName(77, 'المرسلات', 'Al-Mursalat', 'The Emissaries'),
    SurahName(78, 'النبأ', 'An-Naba’', 'The Tidings'),
    SurahName(79, 'النازعات', 'An-Nazi‘at', 'Those who drag forth'),
    SurahName(80, 'عبس', '‘Abasa', 'He frowned'),
    SurahName(81, 'التكوير', 'At-Takwir', 'The Overthrowing'),
    SurahName(82, 'الانفطار', 'Al-Infitar', 'The Cleaving'),
    SurahName(83, 'المطففين', 'Al-Mutaffifin', 'The Defrauding'),
    SurahName(84, 'الانشقاق', 'Al-Inshiqaq', 'The Sundering'),
    SurahName(85, 'البروج', 'Al-Buruj', 'The Mansions of the Stars'),
    SurahName(86, 'الطارق', 'At-Tariq', 'The Nightcomer'),
    SurahName(87, 'الأعلى', 'Al-A‘la', 'The Most High'),
    SurahName(88, 'الغاشية', 'Al-Ghashiyah', 'The Overwhelming'),
    SurahName(89, 'الفجر', 'Al-Fajr', 'The Dawn'),
    SurahName(90, 'البلد', 'Al-Balad', 'The City'),
    SurahName(91, 'الشمس', 'Ash-Shams', 'The Sun'),
    SurahName(92, 'الليل', 'Al-Layl', 'The Night'),
    SurahName(93, 'الضحى', 'Ad-Duha', 'The Morning Hours'),
    SurahName(94, 'الشرح', 'Ash-Sharh', 'The Relief'),
    SurahName(95, 'التين', 'At-Tin', 'The Fig'),
    SurahName(96, 'العلق', 'Al-‘Alaq', 'The Clot'),
    SurahName(97, 'القدر', 'Al-Qadr', 'The Power'),
    SurahName(98, 'البينة', 'Al-Bayyinah', 'The Clear Proof'),
    SurahName(99, 'الزلزلة', 'Az-Zalzalah', 'The Earthquake'),
    SurahName(100, 'العاديات', 'Al-‘Adiyat', 'The Courser'),
    SurahName(101, 'القارعة', 'Al-Qari‘ah', 'The Calamity'),
    SurahName(102, 'التكاثر', 'At-Takathur', 'Competition'),
    SurahName(103, 'العصر', 'Al-‘Asr', 'The Declining Day'),
    SurahName(104, 'الهمزة', 'Al-Humazah', 'The Traducer'),
    SurahName(105, 'الفيل', 'Al-Fil', 'The Elephant'),
    SurahName(106, 'قريش', 'Quraysh', 'Quraysh'),
    SurahName(107, 'الماعون', 'Al-Ma‘un', 'Small Kindnesses'),
    SurahName(108, 'الكوثر', 'Al-Kawthar', 'Abundance'),
    SurahName(109, 'الكافرون', 'Al-Kafirun', 'The Disbelievers'),
    SurahName(110, 'النصر', 'An-Nasr', 'Divine Support'),
    SurahName(111, 'المسد', 'Al-Masad', 'The Palm Fiber'),
    SurahName(112, 'الإخلاص', 'Al-Ikhlas', 'Sincerity'),
    SurahName(113, 'الفلق', 'Al-Falaq', 'The Daybreak'),
    SurahName(114, 'الناس', 'An-Nas', 'Mankind'),
  ];
}
