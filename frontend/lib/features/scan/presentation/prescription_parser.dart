import '../../shared/models/api_models.dart';

/// Structured frequency parsed from a label or OCR text.
class ParsedFrequency {
  const ParsedFrequency({
    required this.timesPerDay,
    this.daysOfWeek,
    this.intervalDays,
    required this.displayText,
  });

  /// How many doses per active day (1–8).
  final int timesPerDay;

  /// Non-null when medication is taken only on specific weekdays.
  /// Integers follow Dart's [DateTime.weekday]: 1=Mon … 7=Sun.
  final List<int>? daysOfWeek;

  /// Non-null when medication is taken every N days (e.g. 2 = every other day).
  final int? intervalDays;

  /// Human-readable label shown to the user (from the original OCR text).
  final String displayText;

  bool get isEveryDay => daysOfWeek == null && (intervalDays == null || intervalDays == 1);
}

// ─── Default clock times for N-times-per-day ──────────────────────────────────

/// Returns sensible default clock times for N doses/day.
/// Times are spread across waking hours (08:00–20:00).
List<({int hour, int minute})> defaultTimesForCount(int n) => switch (n) {
      1 => [(hour: 8, minute: 0)],
      2 => [(hour: 8, minute: 0), (hour: 20, minute: 0)],
      3 => [(hour: 8, minute: 0), (hour: 13, minute: 0), (hour: 19, minute: 0)],
      4 => [(hour: 8, minute: 0), (hour: 12, minute: 0), (hour: 16, minute: 0), (hour: 20, minute: 0)],
      5 => [
          (hour: 7, minute: 0),
          (hour: 10, minute: 0),
          (hour: 13, minute: 0),
          (hour: 16, minute: 0),
          (hour: 20, minute: 0)
        ],
      _ => [(hour: 8, minute: 0)],
    };

// ─── Frequency parser ──────────────────────────────────────────────────────────

/// Parse a frequency string (from OCR or user input) into a [ParsedFrequency].
/// Returns null when the string cannot be interpreted.
ParsedFrequency? parseFrequency(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final s = raw.trim().toLowerCase();

  // ── Already-structured "M times/day" strings (produced by this parser) ──
  final timesPerDayRe = RegExp(r'(\d+)\s*times?/day');
  final tpdMatch = timesPerDayRe.firstMatch(s);
  if (tpdMatch != null) {
    final n = int.tryParse(tpdMatch.group(1)!) ?? 1;
    return ParsedFrequency(timesPerDay: n.clamp(1, 8), displayText: raw.trim());
  }

  // ── Latin abbreviations: OD, BID, TID, QID, QD ──
  if (RegExp(r'\bq\.?d\.?\b|\bo\.?d\.?\b').hasMatch(s)) {
    return ParsedFrequency(timesPerDay: 1, displayText: raw.trim());
  }
  if (RegExp(r'\bb\.?i\.?d\.?\b').hasMatch(s)) {
    return ParsedFrequency(timesPerDay: 2, displayText: raw.trim());
  }
  if (RegExp(r'\bt\.?i\.?d\.?\b').hasMatch(s)) {
    return ParsedFrequency(timesPerDay: 3, displayText: raw.trim());
  }
  if (RegExp(r'\bq\.?i\.?d\.?\b').hasMatch(s)) {
    return ParsedFrequency(timesPerDay: 4, displayText: raw.trim());
  }

  // ── "N times a/per day" — numeric or word ──
  const wordToNum = {
    'once': 1, 'one': 1,
    'twice': 2, 'two': 2,
    'three': 3, 'thrice': 3,
    'four': 4,
    'five': 5,
  };
  final numDayRe = RegExp(
    r'\b(once|twice|thrice|one|two|three|four|five|\d+)\s+times?\s+(a\s+|per\s+)?(day|daily)\b',
  );
  final numDayMatch = numDayRe.firstMatch(s);
  if (numDayMatch != null) {
    final raw1 = numDayMatch.group(1)!;
    final n = wordToNum[raw1] ?? int.tryParse(raw1) ?? 1;
    return ParsedFrequency(timesPerDay: n.clamp(1, 8), displayText: raw.trim());
  }

  // ── "once daily" / "daily" / "每天一次" ──
  if (RegExp(r'\bonce\s+daily\b|\bjust\s+daily\b|\bdaily\b').hasMatch(s) ||
      s.contains('每天一次') ||
      s.contains('一天一次')) {
    return ParsedFrequency(timesPerDay: 1, displayText: raw.trim());
  }

  // ── Chinese times-per-day: 每天N次 / 一天N次 ──
  final chineseDaily = RegExp(r'每天(\d+|[一二三四五六七八九])次|一天(\d+|[一二三四五六七八九])次');
  final cdMatch = chineseDaily.firstMatch(s);
  if (cdMatch != null) {
    final g = cdMatch.group(1) ?? cdMatch.group(2) ?? '1';
    final n = _chineseDigit(g);
    return ParsedFrequency(timesPerDay: n.clamp(1, 8), displayText: raw.trim());
  }

  // ── Every-other-day / every N days ──
  if (RegExp(r'\bevery\s+other\s+day\b|\balternate\s+days?\b').hasMatch(s) ||
      RegExp(r'\bevery\s+2\s+days?\b').hasMatch(s) ||
      s.contains('隔天') ||
      s.contains('隔日')) {
    return ParsedFrequency(timesPerDay: 1, intervalDays: 2, displayText: raw.trim());
  }
  final everyNRe = RegExp(r'\bevery\s+(\d+)\s+days?\b');
  final everyNMatch = everyNRe.firstMatch(s);
  if (everyNMatch != null) {
    final n = int.tryParse(everyNMatch.group(1)!) ?? 1;
    return ParsedFrequency(timesPerDay: 1, intervalDays: n, displayText: raw.trim());
  }

  // ── Weekly patterns ──
  // "once a week" / "weekly"
  if (RegExp(r'\bonce\s+a\s+week\b|\bweekly\b|\bone\s+time\s+(a\s+)?week\b').hasMatch(s) ||
      s.contains('每週一次') ||
      s.contains('每周一次')) {
    return ParsedFrequency(timesPerDay: 1, daysOfWeek: [1], displayText: raw.trim()); // Monday
  }
  // "twice a week"
  if (RegExp(r'\btwice\s+(a\s+)?week\b|\b2\s+times?\s+(a\s+)?week\b').hasMatch(s) ||
      s.contains('每週兩次') ||
      s.contains('每周两次')) {
    return ParsedFrequency(timesPerDay: 1, daysOfWeek: [1, 4], displayText: raw.trim()); // Mon+Thu
  }
  // "three times a week"
  if (RegExp(r'\bthree\s+times?\s+(a\s+)?week\b|\b3\s+times?\s+(a\s+)?week\b').hasMatch(s) ||
      s.contains('每週三次') ||
      s.contains('每周三次')) {
    return ParsedFrequency(timesPerDay: 1, daysOfWeek: [1, 3, 5], displayText: raw.trim()); // Mon+Wed+Fri
  }

  return null;
}

// ─── Prescription text parser ──────────────────────────────────────────────────

/// Parses raw OCR text from Apple Vision into a list of [OCRScanResult].
///
/// Handles Taiwanese pharmacy label format:
///   N.NN#        → total grams  (e.g. "9.00#" → "9g total")
///   (NxM)        → N tablets × M times/day
///   A.C. / P.C.  → before / after meals
///   P.R.N.       → as needed
///   Shared freq  → a frequency-only line applies to all following medications
///   English freq → once daily, BID, TID, every other day, etc.
List<OCRScanResult> parsePrescriptionText(String rawText) {
  final results = <OCRScanResult>[];
  final lines = rawText
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  // Matches a line starting with a drug name (uppercase Latin letter, ≥3 chars)
  final nameStart = RegExp(r'^([A-Z][A-Za-z0-9\-]{1,})');
  // Total grams: e.g. "9.00#" or "4.50 #"
  final gramsRe = RegExp(r'(\d+\.?\d*)\s*#');
  // Dose+frequency: e.g. "(3x3)" "(1x1)" "(2X2)"
  final nxmRe = RegExp(r'\((\d+)\s*[xX×]\s*(\d+)\)');
  // mg/g/ml/mcg: e.g. "500mg" "0.5g"
  final mgRe = RegExp(r'(\d+\.?\d*)\s*(mg|mcg|g|ml|IU)', caseSensitive: false);

  String? sharedFrequency;

  for (final line in lines) {
    if (_isJunkLine(line)) continue;

    // Frequency-only line (no drug name at start) — update shared frequency
    if (!nameStart.hasMatch(line)) {
      final sf = _extractSharedFreq(line, nxmRe);
      if (sf != null) sharedFrequency = sf;
      continue;
    }

    // Extract drug name: everything before the first digit / parenthesis / #
    final rawName = line.split(RegExp(r'[\d\(#]')).first.trim();
    // Remove trailing timing keywords that got mixed in
    final name = rawName
        .replaceAll(
            RegExp(r'\b(A\.C\.|P\.C\.|P\.R\.N\.|AC|PC|PRN)\b',
                caseSensitive: false),
            '')
        .trim();
    if (name.length < 3) continue;

    // Dosage
    String? dosage;
    final gm = gramsRe.firstMatch(line);
    if (gm != null) {
      dosage = '${gm.group(1)}g total';
    } else {
      final mm = mgRe.firstMatch(line);
      if (mm != null) dosage = '${mm.group(1)} ${mm.group(2)!.toLowerCase()}';
    }

    // Frequency — try (NxM), then English patterns, then shared
    String? frequency;
    final fm = nxmRe.firstMatch(line);
    if (fm != null) {
      final tablets = fm.group(1);
      final times = fm.group(2);
      frequency = '$tablets tablet(s), $times times/day';
      sharedFrequency = frequency; // becomes the new shared default
    } else {
      final eng = _extractEnglishFreq(line);
      if (eng != null) {
        frequency = eng;
        sharedFrequency = frequency;
      } else if (sharedFrequency != null) {
        frequency = sharedFrequency;
      }
    }

    // Meal timing
    final upper = line.toUpperCase();
    if (upper.contains('A.C.') ||
        upper.contains(' AC ') ||
        line.contains('飯前')) {
      frequency = _appendNote(frequency, 'before meals');
    } else if (upper.contains('P.C.') ||
        upper.contains(' PC ') ||
        line.contains('飯後')) {
      frequency = _appendNote(frequency, 'after meals');
    }
    if (upper.contains('P.R.N.') ||
        upper.contains('PRN') ||
        line.contains('必要時')) {
      frequency = _appendNote(frequency, 'as needed');
    }

    results.add(OCRScanResult(
      name: name,
      dosage: dosage,
      frequency: frequency,
    ));
  }

  return results;
}

// ─── Helpers ───────────────────────────────────────────────────────────────────

String _appendNote(String? base, String note) =>
    base != null && base.isNotEmpty ? '$base, $note' : note;

/// Returns a frequency string if [line] appears to be a shared-frequency line.
String? _extractSharedFreq(String line, RegExp nxmRe) {
  // (NxM) on its own line
  final m = nxmRe.firstMatch(line);
  if (m != null) return '${m.group(1)} tablet(s), ${m.group(2)} times/day';

  // Chinese patterns: 每天3次, 一天三次, etc.
  final chineseFreq = RegExp(r'(\d+|[一二三四五六七八九])\s*[次回]');
  final cm = chineseFreq.firstMatch(line);
  if (cm != null) {
    final n = _chineseDigit(cm.group(1)!);
    return '$n times/day';
  }

  // English frequency phrases
  return _extractEnglishFreq(line);
}

/// Extract English frequency phrases from a line.
/// Returns a canonical string like "2 times/day" or "every other day".
String? _extractEnglishFreq(String line) {
  final s = line.toLowerCase();

  // BID / TID / QID abbreviations
  if (RegExp(r'\bb\.?i\.?d\.?\b').hasMatch(s)) return '2 times/day';
  if (RegExp(r'\bt\.?i\.?d\.?\b').hasMatch(s)) return '3 times/day';
  if (RegExp(r'\bq\.?i\.?d\.?\b').hasMatch(s)) return '4 times/day';
  if (RegExp(r'\bq\.?d\.?\b|\bo\.?d\.?\b').hasMatch(s)) return '1 times/day';

  // "N times a/per day"
  const wordToNum = {
    'once': 1, 'one': 1,
    'twice': 2, 'two': 2,
    'three': 3, 'thrice': 3,
    'four': 4, 'five': 5,
  };
  final numDayRe = RegExp(
    r'\b(once|twice|thrice|one|two|three|four|five|\d+)\s+times?\s+(a\s+|per\s+)?(day|daily)\b',
  );
  final nm = numDayRe.firstMatch(s);
  if (nm != null) {
    final raw = nm.group(1)!;
    final n = wordToNum[raw] ?? int.tryParse(raw) ?? 1;
    return '$n times/day';
  }

  // "once daily" / "daily"
  if (RegExp(r'\bonce\s+daily\b|\bdaily\b').hasMatch(s)) return '1 times/day';

  // Every other day / every N days
  if (RegExp(r'\bevery\s+other\s+day\b|\balternate\s+days?\b').hasMatch(s)) {
    return 'every other day';
  }
  final everyN = RegExp(r'\bevery\s+(\d+)\s+days?\b').firstMatch(s);
  if (everyN != null) return 'every ${everyN.group(1)} days';

  // Weekly
  if (RegExp(r'\bonce\s+a\s+week\b|\bweekly\b').hasMatch(s)) return 'once a week';
  if (RegExp(r'\btwice\s+(a\s+)?week\b|\b2\s+times?\s+(a\s+)?week\b').hasMatch(s)) {
    return 'twice a week';
  }
  if (RegExp(r'\bthree\s+times?\s+(a\s+)?week\b|\b3\s+times?\s+(a\s+)?week\b').hasMatch(s)) {
    return 'three times a week';
  }

  return null;
}

int _chineseDigit(String s) {
  const map = {
    '一': 1, '二': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
  };
  return map[s] ?? int.tryParse(s) ?? 1;
}

bool _isJunkLine(String line) {
  if (line.length < 3) return true;
  // Pure numbers / dates
  if (RegExp(r'^[\d\s\/\-\:\.]+$').hasMatch(line)) return true;
  // Known header/footer keywords
  const junk = [
    'patient', 'date', 'doctor', 'clinic', 'hospital', 'pharmacist',
    'tel', 'addr', 'fax', 'no.', 'qty', 'days supply',
    '病患', '日期', '醫師', '診所', '醫院', '電話', '地址', '藥師', '健保',
  ];
  final lc = line.toLowerCase();
  return junk.any(lc.contains);
}
