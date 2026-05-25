import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/models/api_models.dart';
import 'med_blue_tokens.dart';
import 'prescription_parser.dart';
import 'scan_controller.dart';

String composeNotesFromOcr(OCRScanResult o) {
  final lines = <String>[];
  if (o.frequency != null && o.frequency!.trim().isNotEmpty) {
    lines.add('Frequency (from label): ${o.frequency!.trim()}');
  }
  if (o.expiryDate != null && o.expiryDate!.trim().isNotEmpty) {
    lines.add('Expiry: ${o.expiryDate!.trim()}');
  }
  if (o.manufacturer != null && o.manufacturer!.trim().isNotEmpty) {
    lines.add('Manufacturer: ${o.manufacturer!.trim()}');
  }
  if (o.warnings.isNotEmpty) {
    lines.add('Warnings on packaging:');
    for (final w in o.warnings) {
      if (w.trim().isNotEmpty) lines.add('• ${w.trim()}');
    }
  }
  return lines.join('\n');
}

String _formatHm(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// Weekday names (Dart weekday: 1=Mon … 7=Sun)
const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class MedicationEntrySheet extends ConsumerStatefulWidget {
  const MedicationEntrySheet({
    super.key,
    this.initialOcr,
    this.initialDrugInfo,
    this.onSaved,
  });

  final OCRScanResult? initialOcr;
  final DrugInfo? initialDrugInfo;
  final VoidCallback? onSaved;

  @override
  ConsumerState<MedicationEntrySheet> createState() => _MedicationEntrySheetState();
}

class _MedicationEntrySheetState extends ConsumerState<MedicationEntrySheet> {
  final _name = TextEditingController();
  final _nameZh = TextEditingController();
  final _dosage = TextEditingController();
  final _notes = TextEditingController();

  final List<TimeOfDay> _times = [];

  /// Weekdays this medication is taken (1=Mon…7=Sun). Null = every day.
  List<int>? _daysOfWeek;

  /// Banner shown when the label specifies a non-daily interval (e.g. every 3 days).
  String? _intervalNote;

  @override
  void initState() {
    super.initState();
    final o = widget.initialOcr;
    if (o != null) {
      _name.text = o.name;
      _nameZh.text = o.nameZh ?? '';
      _dosage.text = o.dosage ?? '';
      _notes.text = composeNotesFromOcr(o);

      // ── Auto-populate schedule from parsed frequency ──────────────────────
      final freq = parseFrequency(o.frequency);
      if (freq != null) {
        final defaults = defaultTimesForCount(freq.timesPerDay);
        _times.addAll(defaults.map((t) => TimeOfDay(hour: t.hour, minute: t.minute)));
        _daysOfWeek = freq.daysOfWeek;
        if (freq.intervalDays != null && freq.intervalDays! > 1) {
          _intervalNote =
              'Label says every ${freq.intervalDays} days. '
              'Set the correct days below or adjust after saving.';
        }
      }
    }

    // Default to 08:00 if nothing was populated
    if (_times.isEmpty) {
      _times.add(const TimeOfDay(hour: 8, minute: 0));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameZh.dispose();
    _dosage.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ── Time pickers ────────────────────────────────────────────────────────────

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
      builder: _themeWrapper,
    );
    if (picked != null && mounted) {
      setState(() => _times[index] = picked);
    }
  }

  Future<void> _addTime() async {
    if (_times.length >= 8) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      builder: _themeWrapper,
    );
    if (picked != null && mounted) {
      setState(() => _times.add(picked));
    }
  }

  void _removeTime(int index) {
    if (_times.length <= 1) return;
    setState(() => _times.removeAt(index));
  }

  Widget _themeWrapper(BuildContext ctx, Widget? child) {
    return Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: ColorScheme.light(
          primary: MedBlueTokens.primary,
          onPrimary: Colors.white,
          surface: MedBlueTokens.background,
          onSurface: MedBlueTokens.ink,
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: MedBlueTokens.background,
          hourMinuteTextColor: WidgetStateColor.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return MedBlueTokens.primaryDark;
            return MedBlueTokens.body;
          }),
        ),
      ),
      child: child!,
    );
  }

  // ── Days of week toggle ─────────────────────────────────────────────────────

  void _toggleDay(int weekday) {
    setState(() {
      if (_daysOfWeek == null) {
        // Switch from "every day" to specific days — start with the tapped day
        _daysOfWeek = [weekday];
      } else {
        final next = List<int>.from(_daysOfWeek!);
        if (next.contains(weekday)) {
          next.remove(weekday);
          if (next.isEmpty) {
            _daysOfWeek = null; // back to "every day"
          } else {
            _daysOfWeek = next..sort();
          }
        } else {
          _daysOfWeek = (next..add(weekday))..sort();
        }
      }
    });
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  Future<void> _submit(ScanController ctrl) async {
    FocusScope.of(context).unfocus();
    await ctrl.saveMedicationWithSchedule(
      name: _name.text,
      nameZh: _nameZh.text,
      dosage: _dosage.text,
      notes: _notes.text,
      times: _times.map(_formatHm).toList(),
      daysOfWeek: _daysOfWeek,
    );
    if (!mounted) return;
    if (ctrl.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ctrl.error!)));
      return;
    }
    widget.onSaved?.call();
    ref.invalidate(dashboardControllerProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Medication and schedule added.')),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scan = ref.watch(scanControllerProvider);
    final ctrl = ref.read(scanControllerProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: h,
      child: Material(
        color: MedBlueTokens.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MedBlueTokens.borderSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.medicationDetails,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: MedBlueTokens.ink),
                    ),
                  ),
                  IconButton(
                    onPressed: scan.isLoading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: MedBlueTokens.ink),
                  ),
                ],
              ),
            ),
            if (widget.initialOcr != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  l10n.reviewAndEdit,
                  style: const TextStyle(color: MedBlueTokens.muted, height: 1.35),
                ),
              ),
            if (widget.initialDrugInfo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MedBlueTokens.accentChip.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: MedBlueTokens.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: MedBlueTokens.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.drugReferenceLoaded,
                          style: TextStyle(
                              color: MedBlueTokens.body.withValues(alpha: 0.95),
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
                children: [
                  Text(l10n.medicineName, style: _label),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        MedBlueTokens.inputDecoration(hint: l10n.medicineNameHint, label: null),
                  ),
                  const SizedBox(height: 14),
                  Text(l10n.chineseNameOptional, style: _label),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameZh,
                    decoration:
                        MedBlueTokens.inputDecoration(hint: '如：二甲雙胍', label: null),
                  ),
                  const SizedBox(height: 14),
                  Text(l10n.dosage, style: _label),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _dosage,
                    decoration:
                        MedBlueTokens.inputDecoration(hint: l10n.dosageHint, label: null),
                  ),
                  const SizedBox(height: 14),

                  // ── Schedule times ─────────────────────────────────────────
                  Text(l10n.schedule, style: _label),
                  const SizedBox(height: 6),
                  ...List.generate(_times.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: scan.isLoading ? null : () => _pickTime(i),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: MedBlueTokens.primaryDark,
                                side: const BorderSide(
                                    color: MedBlueTokens.primary, width: 1.2),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    const Icon(Icons.schedule,
                                        color: MedBlueTokens.primary, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      _formatHm(_times[i]),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800, fontSize: 17),
                                    ),
                                    const Spacer(),
                                    Text(l10n.change,
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (_times.length > 1)
                            IconButton(
                              onPressed:
                                  scan.isLoading ? null : () => _removeTime(i),
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: MedBlueTokens.error),
                            ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed:
                          scan.isLoading || _times.length >= 8 ? null : _addTime,
                      icon: const Icon(Icons.add, color: MedBlueTokens.primary),
                      label: Text(l10n.addAnotherTime,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Days of week ───────────────────────────────────────────
                  Row(
                    children: [
                      Text(l10n.daysOfWeek, style: _label),
                      const SizedBox(width: 8),
                      Text(
                        _daysOfWeek == null ? l10n.everyDay : '',
                        style: const TextStyle(
                            fontSize: 11,
                            color: MedBlueTokens.muted,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      final day = i + 1; // 1=Mon…7=Sun
                      final selected = _daysOfWeek == null || _daysOfWeek!.contains(day);
                      return ChoiceChip(
                        label: Text(_weekdayShort[i]),
                        selected: selected,
                        onSelected: scan.isLoading
                            ? null
                            : (_) => _toggleDay(day),
                        selectedColor: MedBlueTokens.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : MedBlueTokens.body,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        backgroundColor: MedBlueTokens.background,
                        side: BorderSide(
                          color: selected
                              ? MedBlueTokens.primary
                              : MedBlueTokens.borderSubtle,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }),
                  ),
                  if (_daysOfWeek != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.tapDayToToggle,
                        style: const TextStyle(
                            fontSize: 11,
                            color: MedBlueTokens.muted,
                            fontStyle: FontStyle.italic),
                      ),
                    ),

                  // ── Interval note (e.g. "every 3 days") ───────────────────
                  if (_intervalNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 18, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _intervalNote!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: MedBlueTokens.body,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),
                  Text(l10n.descriptionOptional, style: _label),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notes,
                    maxLines: 5,
                    minLines: 3,
                    decoration: MedBlueTokens.inputDecoration(
                      hint: l10n.descriptionHint,
                      label: null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: scan.isLoading ? null : () => _submit(ctrl),
                    style: MedBlueTokens.primaryFilled(),
                    child: Text(scan.isLoading ? 'Saving…' : l10n.saveMedication),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed:
                        scan.isLoading ? null : () => Navigator.of(context).pop(),
                    style: MedBlueTokens.secondaryOutlined(),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
    color: MedBlueTokens.muted,
  );
}
