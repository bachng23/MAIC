import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/scan/presentation/prescription_parser.dart';

void main() {
  // ── parseFrequency ─────────────────────────────────────────────────────────

  group('parseFrequency', () {
    test('BID returns 2 times/day', () {
      final result = parseFrequency('BID');
      expect(result, isNotNull);
      expect(result!.timesPerDay, 2);
    });

    test('TID returns 3 times/day', () {
      final result = parseFrequency('TID');
      expect(result, isNotNull);
      expect(result!.timesPerDay, 3);
    });

    test('QID returns 4 times/day', () {
      final result = parseFrequency('QID');
      expect(result, isNotNull);
      expect(result!.timesPerDay, 4);
    });

    test('Chinese 每天2次 returns 2 times/day', () {
      final result = parseFrequency('每天2次');
      expect(result, isNotNull);
      expect(result!.timesPerDay, 2);
    });

    test('Chinese 一天三次 returns 3 times/day', () {
      final result = parseFrequency('一天三次');
      expect(result, isNotNull);
      expect(result!.timesPerDay, 3);
    });

    test('每週一次 returns weekly (daysOfWeek set)', () {
      final result = parseFrequency('每週一次');
      expect(result, isNotNull);
      expect(result!.daysOfWeek, isNotNull);
      expect(result.daysOfWeek, isNotEmpty);
    });

    test('once daily returns 1 times/day', () {
      final result = parseFrequency('once daily');
      expect(result, isNotNull);
      expect(result!.timesPerDay, 1);
    });

    test('every other day returns intervalDays 2', () {
      final result = parseFrequency('every other day');
      expect(result, isNotNull);
      expect(result!.intervalDays, 2);
    });

    test('null input returns null', () {
      expect(parseFrequency(null), isNull);
    });

    test('empty string returns null', () {
      expect(parseFrequency(''), isNull);
    });

    test('whitespace-only string returns null', () {
      expect(parseFrequency('   '), isNull);
    });

    test('twice a week returns daysOfWeek with 2 entries', () {
      final result = parseFrequency('twice a week');
      expect(result, isNotNull);
      expect(result!.daysOfWeek, isNotNull);
      expect(result.daysOfWeek!.length, 2);
    });

    test('three times a week returns daysOfWeek with 3 entries', () {
      final result = parseFrequency('three times a week');
      expect(result, isNotNull);
      expect(result!.daysOfWeek, isNotNull);
      expect(result.daysOfWeek!.length, 3);
    });

    test('every 3 days returns intervalDays 3', () {
      final result = parseFrequency('every 3 days');
      expect(result, isNotNull);
      expect(result!.intervalDays, 3);
    });

    test('displayText preserves original input', () {
      final result = parseFrequency('  BID  ');
      expect(result, isNotNull);
      expect(result!.displayText, 'BID');
    });

    test('isEveryDay true for plain daily frequency', () {
      final result = parseFrequency('once daily');
      expect(result, isNotNull);
      expect(result!.isEveryDay, isTrue);
    });

    test('isEveryDay false for every-other-day', () {
      final result = parseFrequency('every other day');
      expect(result, isNotNull);
      expect(result!.isEveryDay, isFalse);
    });
  });

  // ── defaultTimesForCount ───────────────────────────────────────────────────

  group('defaultTimesForCount', () {
    test('1 returns single morning dose at 08:00', () {
      final times = defaultTimesForCount(1);
      expect(times.length, 1);
      expect(times.first.hour, 8);
      expect(times.first.minute, 0);
    });

    test('2 returns morning and evening', () {
      final times = defaultTimesForCount(2);
      expect(times.length, 2);
      expect(times.first.hour, 8);
      expect(times.last.hour, 20);
    });

    test('3 returns three spread times', () {
      final times = defaultTimesForCount(3);
      expect(times.length, 3);
    });

    test('4 returns four times', () {
      final times = defaultTimesForCount(4);
      expect(times.length, 4);
    });

    test('5 returns five times', () {
      final times = defaultTimesForCount(5);
      expect(times.length, 5);
    });

    test('out-of-range falls back to single morning dose', () {
      final times = defaultTimesForCount(99);
      expect(times.length, 1);
      expect(times.first.hour, 8);
    });
  });

  // ── parsePrescriptionText ──────────────────────────────────────────────────

  group('parsePrescriptionText', () {
    test('extracts drug name from simple line', () {
      final results = parsePrescriptionText('Aspirin 100mg\n');
      expect(results, isNotEmpty);
      expect(results.first.name, contains('Aspirin'));
    });

    test('extracts dosage mg from line', () {
      final results = parsePrescriptionText('Metformin 500mg once daily\n');
      expect(results, isNotEmpty);
      expect(results.first.dosage, contains('500'));
    });

    test('NxM pattern sets correct frequency', () {
      final results = parsePrescriptionText('Atorvastatin (1x1)\n');
      expect(results, isNotEmpty);
      expect(results.first.frequency, contains('times/day'));
    });

    test('AC meal timing appended to frequency', () {
      final results = parsePrescriptionText('Metformin 500mg BID A.C.\n');
      expect(results, isNotEmpty);
      expect(results.first.frequency, contains('before meals'));
    });

    test('PC meal timing appended to frequency', () {
      final results = parsePrescriptionText('Metformin 500mg BID P.C.\n');
      expect(results, isNotEmpty);
      expect(results.first.frequency, contains('after meals'));
    });

    test('PRN flag appended to frequency', () {
      final results = parsePrescriptionText('Ibuprofen 400mg P.R.N.\n');
      expect(results, isNotEmpty);
      expect(results.first.frequency, contains('as needed'));
    });

    test('junk-only lines are skipped', () {
      const junk = 'patient: John\ndate: 2025-01-01\ndoctor: Smith\n';
      final results = parsePrescriptionText(junk);
      expect(results, isEmpty);
    });

    test('very short lines are skipped', () {
      final results = parsePrescriptionText('AB\n');
      expect(results, isEmpty);
    });

    test('shared frequency (NxM on own line) applies to next drug', () {
      const text = '(2x3)\nMetformin 500mg\n';
      final results = parsePrescriptionText(text);
      expect(results, isNotEmpty);
      expect(results.first.frequency, contains('times/day'));
    });

    test('multiple drugs are all returned', () {
      const text = 'Aspirin 100mg BID\nMetformin 500mg TID\n';
      final results = parsePrescriptionText(text);
      expect(results.length, 2);
    });

    test('gram total notation is parsed', () {
      final results = parsePrescriptionText('Powder 9.00# once daily\n');
      expect(results, isNotEmpty);
      expect(results.first.dosage, contains('9'));
      expect(results.first.dosage, contains('g total'));
    });

    test('empty text returns empty list', () {
      final results = parsePrescriptionText('');
      expect(results, isEmpty);
    });

    test('drug name shorter than 3 chars is skipped', () {
      // "AB 100mg" — name "AB" is only 2 chars after split.
      final results = parsePrescriptionText('AB 100mg\n');
      expect(results, isEmpty);
    });
  });
}
