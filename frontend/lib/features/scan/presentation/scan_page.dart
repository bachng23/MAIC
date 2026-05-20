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
  final now = DateTime.now();
  int minutesFromNow(String t) {
    final parts = t.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final scheduled = DateTime(now.year, now.month, now.day, h, m);
    return now.difference(scheduled).inMinutes.abs();
  }
  list.sort((a, b) => minutesFromNow(a.timeLabel).compareTo(minutesFromNow(b.timeLabel)));
  return list;
}

/// Returns doses whose scheduled time is within [windowMinutes] of now.
List<_UpcomingDose> _dueNowDoses(List<_UpcomingDose> doses, {int windowMinutes = 15}) {
  final now = DateTime.now();
  return doses.where((d) {
    if (d.timeLabel.isEmpty) return false;
    final parts = d.timeLabel.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    final scheduled = DateTime(now.year, now.month, now.day, h, m);
    return now.difference(scheduled).inMinutes.abs() <= windowMinutes;
  }).toList();
}

List<_PharmacistNoteEntry> _pharmacistNotesForUser(DashboardViewData data) {
  final entries = <_PharmacistNoteEntry>[];
  for (final med in data.medications.where((m) => m.isActive)) {
    final sections = <_NoteSection>[];
    if (med.notes != null && med.notes!.trim().isNotEmpty) {
      sections.add(_NoteSection(label: 'Notes', lines: [med.notes!.trim()]));
    }
    final drug = med.drugInfo;
    if (drug != null) {
      if (drug.mainEffects.trim().isNotEmpty) {
        sections.add(_NoteSection(label: 'Effects', lines: [drug.mainEffects.trim()]));
      }
      if (drug.elderlyNotes != null && drug.elderlyNotes!.trim().isNotEmpty) {
        sections.add(_NoteSection(label: 'Elderly caution', lines: [drug.elderlyNotes!.trim()]));
      }
      final warnings = drug.warnings.map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
      if (warnings.isNotEmpty) {
        sections.add(_NoteSection(label: 'Warnings', lines: warnings));
      }
    }
    if (sections.isEmpty) continue;
    entries.add(_PharmacistNoteEntry(medicationName: med.name, sections: sections));
  }
  return entries;
}

class _NoteSection {
  const _NoteSection({required this.label, required this.lines});
  final String label;
  final List<String> lines;
}

class _PharmacistNoteEntry {
  const _PharmacistNoteEntry({required this.medicationName, required this.sections});
  final String medicationName;
  final List<_NoteSection> sections;
}

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  /// Logs every dose in [dueDoses] as taken, then navigates to Monitor.
  Future<void> _confirmAll(List<_UpcomingDose> dueDoses) async {
    if (dueDoses.isEmpty) return;
    final scan = ref.read(scanControllerProvider);
    int succeeded = 0;
    for (final dose in dueDoses) {
      final ok = await scan.logDoseTaken(
        scheduleId: dose.scheduleId,
        medicationId: dose.medication.id,
      );
      if (ok) succeeded++;
    }
    if (!mounted) return;
    ref.invalidate(dashboardControllerProvider);
    if (succeeded == dueDoses.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $succeeded dose${succeeded > 1 ? 's' : ''} confirmed — monitoring started'),
          backgroundColor: const Color(0xFF0066CC),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/health');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$succeeded/${dueDoses.length} confirmed. ${scan.error ?? ''}'),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
    // Show loading overlay while OCR runs
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _OcrLoadingDialog(),
    );

    await ref.read(scanControllerProvider).runOcrFromImage(imageFile);

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // dismiss loading overlay

    final s = ref.read(scanControllerProvider);

    if (s.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.error!),
          backgroundColor: const Color(0xFFBA1A1A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (s.scanResults.isEmpty) return;

    void onDone() {
      if (mounted) setState(() {});
    }

    // Single medication: use the existing review sheet directly.
    if (s.scanResults.length == 1) {
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
      return;
    }

    // Multiple medications: show a picker sheet listing all detected meds.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MultiMedPickerSheet(
        results: s.scanResults,
        primaryDrugInfo: s.drugInfo,
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
              else ...[
                // ── Take All Due Now banner ────────────────────────────────────
                Builder(builder: (context) {
                  final dueNow = _dueNowDoses(doses);
                  if (dueNow.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF004E9F), Color(0xFF0066CC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Row(
                      children: [
                        const Icon(Icons.medication_liquid, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${dueNow.length} dose${dueNow.length > 1 ? 's' : ''} due now',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                dueNow.map((d) => d.medication.name).join(', '),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: scan.isLoading ? null : () => _confirmAll(dueNow),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF004E9F),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                          child: const Text('Take All'),
                        ),
                      ],
                    ),
                  );
                }),

                // ── Individual dose cards ──────────────────────────────────────
                for (var i = 0; i < doses.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _GlassDoseCard(
                    dose: doses[i],
                    isPrimary: i == 0,
                    isDueNow: _dueNowDoses(doses).any((d) => d.scheduleId == doses[i].scheduleId),
                    onConfirm: () async {
                      final ok = await ref.read(scanControllerProvider).logDoseTaken(
                            scheduleId: doses[i].scheduleId,
                            medicationId: doses[i].medication.id,
                          );
                      if (!context.mounted) return;
                      if (ok) {
                        ref.invalidate(dashboardControllerProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ ${doses[i].medication.name} confirmed'),
                            backgroundColor: const Color(0xFF0066CC),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        final err = ref.read(scanControllerProvider).error;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(err ?? 'Failed to log dose'),
                            backgroundColor: const Color(0xFFBA1A1A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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
    required this.isDueNow,
    required this.onConfirm,
    required this.onRemindMe,
    required this.busy,
  });

  final _UpcomingDose dose;
  final bool isPrimary;
  final bool isDueNow;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onRemindMe;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final dosage = dose.medication.dosage ?? '—';
    final borderColor = isDueNow ? const Color(0xFF0066CC) : const Color(0xFFCDD5DB);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: borderColor, width: 8)),
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
                  Icon(Icons.medication, color: isDueNow ? const Color(0xFF0066CC) : const Color(0xFFADB5BD)),
                  const SizedBox(width: 8),
                  Text(dose.medication.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              if (isDueNow && isPrimary)
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
              Icon(Icons.schedule, size: 18, color: isDueNow ? const Color(0xFF3E4946) : const Color(0xFFADB5BD)),
              const SizedBox(width: 6),
              Text(
                dose.timeLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDueNow ? null : const Color(0xFFADB5BD),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (busy || !isDueNow) ? null : onConfirm,
                  icon: const Icon(Icons.check_circle),
                  label: Text(isDueNow ? 'Confirm Intake' : 'Not yet due'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDueNow ? const Color(0xFF0066CC) : const Color(0xFFE8EAED),
                    foregroundColor: isDueNow ? Colors.white : const Color(0xFFADB5BD),
                    disabledBackgroundColor: const Color(0xFFE8EAED),
                    disabledForegroundColor: const Color(0xFFADB5BD),
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
      decoration: BoxDecoration(
        color: const Color(0xFFFFDDB8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF071E27),
                  child: Icon(Icons.info_outline, color: Colors.orange.shade100),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Pharmacist\'s Notes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),

          // ── Empty state ──────────────────────────────────────────────────────
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'No pharmacist notes yet. Add medications with drug info to see guidance here.',
                style: TextStyle(color: const Color(0xFF2A1700).withValues(alpha: 0.7), height: 1.4),
              ),
            )

          // ── Expandable tiles per medication ─────────────────────────────────
          else
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _NoteExpansionTile(
                      entry: entries[i],
                      isLast: i == entries.length - 1,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteExpansionTile extends StatefulWidget {
  const _NoteExpansionTile({required this.entry, required this.isLast});
  final _PharmacistNoteEntry entry;
  final bool isLast;

  @override
  State<_NoteExpansionTile> createState() => _NoteExpansionTileState();
}

class _NoteExpansionTileState extends State<_NoteExpansionTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Divider between tiles
        Container(height: 1, color: const Color(0xFFE8C07A)),

        // Tap row — medication name + chevron
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.medication_outlined, size: 18, color: Color(0xFF6B3A00)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.entry.medicationName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF2A1700),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B3A00)),
                ),
              ],
            ),
          ),
        ),

        // Expanded content
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _expanded
              ? Padding(
                  padding: EdgeInsets.fromLTRB(
                    20, 0, 20, widget.isLast ? 20 : 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final section in widget.entry.sections) ...[
                        const SizedBox(height: 10),
                        Text(
                          section.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF6B3A00),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (section.lines.length == 1)
                          Text(
                            section.lines.first,
                            style: const TextStyle(
                              color: Color(0xFF2A1700),
                              height: 1.45,
                              fontSize: 14,
                            ),
                          )
                        else
                          for (final line in section.lines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: Color(0xFF6B3A00), fontWeight: FontWeight.w700)),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: const TextStyle(
                                        color: Color(0xFF2A1700),
                                        height: 1.45,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Multi-medication picker sheet ─────────────────────────────────────────────
// Shown when OCR detects more than one medication on a prescription.
// User taps "Add" on each card to open the review/schedule sheet.

class _MultiMedPickerSheet extends ConsumerStatefulWidget {
  const _MultiMedPickerSheet({
    required this.results,
    required this.primaryDrugInfo,
    required this.onSaved,
  });

  final List<OCRScanResult> results;
  final DrugInfo? primaryDrugInfo;
  final VoidCallback onSaved;

  @override
  ConsumerState<_MultiMedPickerSheet> createState() => _MultiMedPickerSheetState();
}

class _MultiMedPickerSheetState extends ConsumerState<_MultiMedPickerSheet> {
  // Track which medications have been added so we can show a checkmark.
  final Set<int> _added = {};

  Future<void> _openEntry(int index) async {
    final ocr = widget.results[index];
    // Only the first result gets the pre-fetched drug info.
    final info = index == 0 ? widget.primaryDrugInfo : null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MedicationEntrySheet(
        initialOcr: ocr,
        initialDrugInfo: info,
        onSaved: () {
          setState(() => _added.add(index));
          widget.onSaved();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom + 16;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCDD5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.medication, color: Color(0xFF0066CC), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.results.length} Medications Detected',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0B3A70)),
                    ),
                    const Text(
                      'Tap Add to review and schedule each one',
                      style: TextStyle(fontSize: 13, color: Color(0xFF4C616C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Constrain height so long lists scroll
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.55,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.results.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final r = widget.results[i];
                final done = _added.contains(i);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: done ? const Color(0xFF2E7D32) : const Color(0xFFDDE3EA),
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x08191C1E), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: done ? const Color(0xFFE8F5E9) : const Color(0xFFE6EFFE),
                        child: Icon(
                          done ? Icons.check_circle : Icons.medication_outlined,
                          color: done ? const Color(0xFF2E7D32) : const Color(0xFF0066CC),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            if (r.nameZh != null)
                              Text(r.nameZh!, style: const TextStyle(color: Color(0xFF4C616C), fontSize: 13)),
                            if (r.dosage != null || r.frequency != null)
                              Text(
                                [if (r.dosage != null) r.dosage!, if (r.frequency != null) r.frequency!].join(' · '),
                                style: const TextStyle(color: Color(0xFF4C616C), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      done
                          ? const Text(
                              'Added',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            )
                          : FilledButton(
                              onPressed: () => _openEntry(i),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0066CC),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              child: const Text('Add'),
                            ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              _added.length == widget.results.length ? 'Done' : 'Skip Remaining',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── OCR loading overlay ───────────────────────────────────────────────────────

class _OcrLoadingDialog extends StatelessWidget {
  const _OcrLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // prevent back-button dismissal during OCR
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Color(0xFF0066CC),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Analysing medication…',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0B3A70),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reading label and fetching drug info',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
