import 'backend_models.dart';

class MedicationDraftParser {
  const MedicationDraftParser();

  MedicationDraft parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return const MedicationDraft(name: 'Unknown medication');
    }

    final dosageMatch = RegExp(
      r'(\d+(?:\.\d+)?)\s?(mg|mcg|g|ml|iu)',
      caseSensitive: false,
    ).firstMatch(rawText);

    final tabletDoseLine = lines.cast<String?>().firstWhere(
          (line) =>
              line != null &&
              RegExp(r'(\d+\s*錠|\d+\s*カプセル|1回\d+\s*錠)').hasMatch(line),
          orElse: () => null,
        );

    final frequencyLine = lines.cast<String?>().firstWhere(
          (line) =>
              line != null &&
              RegExp(
                r'(once|twice|daily|morning|evening|bedtime|after meals|before meals)',
                caseSensitive: false,
              ).hasMatch(line),
          orElse: () => null,
        );

    final primaryEnglishName = lines.cast<String?>().firstWhere(
          (line) =>
              line != null &&
              RegExp(r'^[A-Z][A-Z0-9\s\-]{2,}$').hasMatch(line) &&
              !_isManufacturerLine(line),
          orElse: () => null,
        );

    final fallbackEnglishName = lines.cast<String?>().firstWhere(
          (line) =>
              line != null &&
              RegExp(r'[A-Za-z]{3,}').hasMatch(line) &&
              !_isManufacturerLine(line),
          orElse: () => null,
        );

    final warningLines = lines
        .where((line) => RegExp(r'(warning|caution|avoid|do not)', caseSensitive: false).hasMatch(line))
        .toList();

    final name = _cleanName(primaryEnglishName ?? fallbackEnglishName ?? lines.first);
    final nameZh = lines.cast<String?>().firstWhere(
          (line) =>
              line != null &&
              RegExp(r'[\u4e00-\u9fff]').hasMatch(line) &&
              !_isCategoryLine(line),
          orElse: () => null,
        );

    return MedicationDraft(
      name: name,
      nameZh: nameZh,
      dosage: dosageMatch?.group(0) ?? tabletDoseLine,
      frequency: frequencyLine,
      warnings: warningLines,
      sourceRawText: rawText,
    );
  }

  String _cleanName(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isCategoryLine(String value) {
    return RegExp(r'(第\d+類|医薬品|薬品)', caseSensitive: false).hasMatch(value);
  }

  bool _isManufacturerLine(String value) {
    return RegExp(r'^(bayer|pfizer|roche|gsk|novartis)$', caseSensitive: false)
        .hasMatch(value.trim());
  }
}
