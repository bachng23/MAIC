import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/providers.dart';
import '../../shared/data/mediguard_api_service.dart';
import '../../shared/models/api_models.dart';
import 'med_blue_tokens.dart';
import 'medication_entry_sheet.dart';
import 'medication_intake_controller.dart';
import 'multi_med_review_sheet.dart';
import 'scanner_screen.dart';

class _UpcomingDose {
  const _UpcomingDose({
    required this.scheduleId,
    required this.medication,
    required this.timeLabel,
  });

  final String scheduleId;
  final MedicationOut medication;
  final String timeLabel;
}

List<_UpcomingDose> _upcomingDoses(DashboardViewData data, MedicationIntakeController intake) {
  final medById = {for (final m in data.medications) m.id: m};
  final list = <_UpcomingDose>[];
  for (final s in data.schedules.where((x) => x.isActive)) {
    final med = medById[s.medicationId];
    if (med == null) continue;
    for (final t in s.times) {
      if (!intake.isDosePendingToday(s.id)) continue;
      list.add(_UpcomingDose(scheduleId: s.id, medication: med, timeLabel: t));
    }
  }
  list.sort((a, b) => a.timeLabel.compareTo(b.timeLabel));
  return list;
}

List<_PharmacistNoteEntry> _pharmacistNotesForUser(DashboardViewData data) {
  final entries = <_PharmacistNoteEntry>[];
  for (final med in data.medications.where((m) => m.isActive)) {
    final parts = <String>[];
    if (med.notes != null && med.notes!.trim().isNotEmpty) {
      parts.add(med.notes!.trim());
    }
    final drug = med.drugInfo;
    if (drug != null) {
      if (drug.mainEffects.trim().isNotEmpty) parts.add(drug.mainEffects.trim());
      if (drug.elderlyNotes != null && drug.elderlyNotes!.trim().isNotEmpty) {
        parts.add(drug.elderlyNotes!.trim());
      }
      for (final w in drug.warnings) {
        if (w.trim().isNotEmpty) parts.add(w.trim());
      }
    }
    if (parts.isEmpty) continue;
    entries.add(_PharmacistNoteEntry(medicationName: med.name, text: parts.join(' ')));
  }
  return entries;
}

class _PharmacistNoteEntry {
  const _PharmacistNoteEntry({required this.medicationName, required this.text});
  final String medicationName;
  final String text;
}

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  void _openManualMedicationEntry() {
    ref.read(scanControllerProvider).clearForNewEntry();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MedicationEntrySheet(),
    );
  }

  /// Opens the full-screen [ScannerScreen] (covers bottom nav via root navigator).
  /// Returns the captured [File], or `null` if the user backed out.
  /// Returns the string `'gallery'` if the user chose "Upload from Photos".
  Future<void> _openScanner() async {
    final result = await Navigator.of(context, rootNavigator: true).push<Object>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (!mounted) return;

    if (result == 'gallery') {
      // User tapped "Upload from Photos" inside the scanner
      await _pickFromGallery();
    } else if (result is File) {
      await _runOcrAndOpenReview(result);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    await _runOcrAndOpenReview(File(picked.path));
  }

  Future<void> _runOcrAndOpenReview(File imageFile) async {
    await ref.read(scanControllerProvider).runOcrFromImage(imageFile);
    if (!mounted) return;
    final s = ref.read(scanControllerProvider);
    if (s.error != null || s.scanResult == null) return;
    if (!mounted) return;

    void onDone() {
      if (mounted) setState(() {});
    }

    // Multiple medications → list review sheet
    if (s.scanResults != null && s.scanResults!.length > 1) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => MultiMedReviewSheet(
          medications: s.scanResults!,
          onAllSaved: onDone,
        ),
      );
      return;
    }

    // Single medication → entry sheet
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicationEntrySheet(
        initialOcr: s.scanResult,
        initialDrugInfo: s.drugInfo,
        onSaved: onDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scan = ref.watch(scanControllerProvider);
    final dash = ref.watch(dashboardControllerProvider);
    final intake = ref.watch(medicationIntakeControllerProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 88;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: dash.when(
        data: (data) {
          final doses = _upcomingDoses(data, intake);
          final remaining = doses.length;
          final pharmacistNotes = _pharmacistNotesForUser(data);
          final watchDose = doses.isNotEmpty
              ? doses.first
              : (data.medications.where((m) => m.isActive).isNotEmpty
                  ? _UpcomingDose(
                      scheduleId: '',
                      medication: data.medications.firstWhere((m) => m.isActive),
                      timeLabel: '',
                    )
                  : null);
          return ListView(
            padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset),
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFE6E8EA),
                    child: Icon(Icons.person, color: Color(0xFF0066CC)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'MediAgent',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0B3A70)),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF0B3A70)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0066CC), Color(0xFF004E9F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.photo_camera, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Scan New Medication',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Point your camera at the pharmacy label',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _openScanner,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: MedBlueTokens.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Open Scanner'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _openManualMedicationEntry,
                      icon: const Icon(Icons.edit_note_outlined, color: Colors.white),
                      label: const Text(
                        'Enter medication manually',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Colors.white, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODAY\'S REGIMEN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Color(0xFF855300),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upcoming Doses',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  Text(
                    '$remaining remaining',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0066CC)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (doses.isEmpty)
                const Text(
                  'All doses for today are confirmed, or none are scheduled yet. Add a medication above to get started.',
                )
              else
                for (var i = 0; i < doses.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _GlassDoseCard(
                    dose: doses[i],
                    isPrimary: i == 0,
                    onConfirm: () async {
                      final ok = await ref.read(scanControllerProvider).logDoseTaken(
                            scheduleId: doses[i].scheduleId,
                            medicationId: doses[i].medication.id,
                          );
                      if (context.mounted && ok) {
                        ref.invalidate(dashboardControllerProvider);
                      }
                    },
                    onRemindMe: () async {
                      await ref.read(medicationNotificationServiceProvider).scheduleOneOffReminder(
                            scheduleId: doses[i].scheduleId,
                            medicationName: doses[i].medication.name,
                            dosage: doses[i].medication.dosage,
                            scheduledTime: doses[i].timeLabel,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reminder scheduled for this dose.')),
                        );
                      }
                    },
                    busy: scan.isLoading,
                  ),
                ],
              if (scan.error != null) ...[
                const SizedBox(height: 12),
                Text(scan.error!, style: const TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w600)),
              ],
              if (watchDose != null && intake.showSideEffectWatch) ...[
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth > 720;
                    final sideEffect = _SideEffectWatchCard(
                      medication: watchDose.medication,
                      onLog: () => context.go('/health'),
                      onDismiss: () => ref.read(medicationIntakeControllerProvider).dismissSideEffectWatch(),
                    );
                    final note = _PharmacistNoteCard(entries: pharmacistNotes);
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: sideEffect),
                          const SizedBox(width: 14),
                          Expanded(child: note),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        sideEffect,
                        const SizedBox(height: 14),
                        note,
                      ],
                    );
                  },
                ),
              ] else if (pharmacistNotes.isNotEmpty) ...[
                const SizedBox(height: 22),
                _PharmacistNoteCard(entries: pharmacistNotes),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
      ),
    );
  }
}



class _GlassDoseCard extends StatelessWidget {
  const _GlassDoseCard({
    required this.dose,
    required this.isPrimary,
    required this.onConfirm,
    required this.onRemindMe,
    required this.busy,
  });

  final _UpcomingDose dose;
  final bool isPrimary;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onRemindMe;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final dosage = dose.medication.dosage ?? '—';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: Color(0xFF0066CC), width: 8)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.92),
            Colors.white.withValues(alpha: 0.72),
          ],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x0F191C1E), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medication, color: Color(0xFF0066CC)),
                  const SizedBox(width: 8),
                  Text(dose.medication.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1E4FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('NOW', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF004A99))),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dose.medication.drugInfo?.mainEffects ?? 'Scheduled dose',
            style: const TextStyle(color: Color(0xFF3E4946), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            dosage,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: Color(0xFF3E4946)),
              const SizedBox(width: 6),
              Text(dose.timeLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onConfirm,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Confirm Intake'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0066CC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: busy ? null : onRemindMe,
                child: const Text('Remind Me'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideEffectWatchCard extends StatelessWidget {
  const _SideEffectWatchCard({
    required this.medication,
    required this.onLog,
    required this.onDismiss,
  });

  final MedicationOut medication;
  final VoidCallback onLog;
  final VoidCallback onDismiss;

  String get _title {
    final dosage = medication.dosage?.trim();
    if (dosage != null && dosage.isNotEmpty) {
      return '${medication.name} $dosage';
    }
    return medication.name;
  }

  String get _body {
    final effects = medication.drugInfo?.sideEffects ?? const [];
    if (effects.isNotEmpty) {
      final summary = effects.take(3).join(', ');
      return 'Watch for possible side effects after your dose: $summary. Log any symptoms you notice.';
    }
    return 'We\'re monitoring how you respond after taking $_title. Log any nausea, fatigue, or unusual symptoms.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF866300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart, color: Color(0xFFFFE6B7)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'SIDE EFFECT WATCH',
                  style: TextStyle(
                    color: Color(0xFFFFE6B7),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Dismiss',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _title,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            _body,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), height: 1.35, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                onPressed: onLog,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Log Symptom'),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Dismiss', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PharmacistNoteCard extends StatelessWidget {
  const _PharmacistNoteCard({required this.entries});

  final List<_PharmacistNoteEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDB8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF071E27),
                child: Icon(Icons.info_outline, color: Colors.orange.shade100),
              ),
              const SizedBox(width: 12),
              const Text('Pharmacist\'s Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Text(
              'No pharmacist notes yet. Add medications with notes or drug info to see guidance here.',
              style: TextStyle(fontStyle: FontStyle.italic, height: 1.4, color: Color(0xFF2A1700)),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Text(
                entries[i].medicationName,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2A1700)),
              ),
              const SizedBox(height: 4),
              Text(
                entries[i].text,
                style: const TextStyle(fontStyle: FontStyle.italic, height: 1.4, color: Color(0xFF2A1700)),
              ),
            ],
        ],
      ),
    );
  }
}
