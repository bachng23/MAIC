import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../shared/models/api_models.dart';
import 'med_blue_tokens.dart';
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
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 9, minute: 0)];

  @override
  void initState() {
    super.initState();
    final o = widget.initialOcr;
    if (o != null) {
      _name.text = o.name;
      _nameZh.text = o.nameZh ?? '';
      _dosage.text = o.dosage ?? '';
      _notes.text = composeNotesFromOcr(o);
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

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
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
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: MedBlueTokens.primary,
              onPrimary: Colors.white,
              surface: MedBlueTokens.background,
              onSurface: MedBlueTokens.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _times.add(picked));
    }
  }

  void _removeTime(int index) {
    if (_times.length <= 1) return;
    setState(() => _times.removeAt(index));
  }

  Future<void> _submit(ScanController ctrl) async {
    FocusScope.of(context).unfocus();
    await ctrl.saveMedicationWithSchedule(
      name: _name.text,
      nameZh: _nameZh.text,
      dosage: _dosage.text,
      notes: _notes.text,
      times: _times.map(_formatHm).toList(),
    );
    if (!mounted) return;
    if (ctrl.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ctrl.error!)));
      return;
    }
    if (ctrl.createdMedication == null) return;
    widget.onSaved?.call();
    ref.invalidate(dashboardControllerProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved: ${ctrl.createdMedication!.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = ref.watch(scanControllerProvider);
    final ctrl = ref.read(scanControllerProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
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
                    const Expanded(
                      child: Text(
                        'Medication details',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: MedBlueTokens.ink),
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Review and edit fields from your scan before saving.',
                    style: TextStyle(color: MedBlueTokens.muted, height: 1.35),
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
                      border: Border.all(color: MedBlueTokens.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: MedBlueTokens.primary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Drug reference loaded. It will be stored with this medication when you save.',
                            style: TextStyle(color: MedBlueTokens.body.withValues(alpha: 0.95), height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Text('Medicine name', style: _label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: MedBlueTokens.inputDecoration(hint: 'e.g. Metformin', label: null),
                    ),
                    const SizedBox(height: 14),
                    Text('Chinese name (optional)', style: _label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameZh,
                      decoration: MedBlueTokens.inputDecoration(hint: '如：二甲雙胍', label: null),
                    ),
                    const SizedBox(height: 14),
                    Text('Dosage', style: _label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _dosage,
                      decoration: MedBlueTokens.inputDecoration(hint: 'e.g. 500mg', label: null),
                    ),
                    const SizedBox(height: 14),
                    Text('Schedule', style: _label),
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
                                  side: const BorderSide(color: MedBlueTokens.primary, width: 1.2),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.schedule, color: MedBlueTokens.primary, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        _formatHm(_times[i]),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                                      ),
                                      const Spacer(),
                                      const Text('Change', style: TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_times.length > 1)
                              IconButton(
                                onPressed: scan.isLoading ? null : () => _removeTime(i),
                                icon: const Icon(Icons.remove_circle_outline, color: MedBlueTokens.error),
                              ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: scan.isLoading || _times.length >= 8 ? null : _addTime,
                        icon: const Icon(Icons.add, color: MedBlueTokens.primary),
                        label: const Text('Add another time', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Description (optional)', style: _label),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notes,
                      maxLines: 5,
                      minLines: 3,
                      decoration: MedBlueTokens.inputDecoration(
                        hint: 'Notes, instructions, or OCR context…',
                        label: null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: scan.isLoading ? null : () => _submit(ctrl),
                      style: MedBlueTokens.primaryFilled(),
                      child: Text(scan.isLoading ? 'Saving…' : 'Save medication'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: scan.isLoading ? null : () => Navigator.of(context).pop(),
                      style: MedBlueTokens.secondaryOutlined(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
