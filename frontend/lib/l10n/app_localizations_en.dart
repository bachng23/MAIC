// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MediAgent';

  @override
  String get navHome => 'Home';

  @override
  String get navScan => 'Scan';

  @override
  String get navHealth => 'Health';

  @override
  String get navCompliance => 'Reports';

  @override
  String get navProfile => 'Profile';

  @override
  String get todaysMedications => 'Today\'s Medications';

  @override
  String dosesToday(int count) {
    return '$count dose(s) today';
  }

  @override
  String get noMedicationsAdded => 'No medications added yet';

  @override
  String get viewFullSchedule => 'View Full Schedule';

  @override
  String get healthMonitoring => 'Health Monitoring';

  @override
  String get heartRate => 'Heart Rate';

  @override
  String get bloodOxygen => 'Blood O₂';

  @override
  String get liveFromAppleWatch => 'Live from Apple Watch';

  @override
  String get fromIPhone => 'From iPhone';

  @override
  String get lastReadingShown => 'Last reading shown';

  @override
  String get noDataYet => 'No data yet — confirm a dose to start';

  @override
  String get weeklyReport => 'Weekly Report';

  @override
  String get medicationAdherence => 'Medication adherence';

  @override
  String get emergency => 'Emergency';

  @override
  String get noContactsAdded => 'No contacts added yet';

  @override
  String get emergencyAlerts => 'Emergency Alerts';

  @override
  String get healthMonitor => 'Health Monitor';

  @override
  String get medicationLogId => 'Medication Log ID';

  @override
  String get enterLogId => 'Enter log_id from taken medication flow';

  @override
  String get bpm => 'BPM';

  @override
  String get safe => 'Safe';

  @override
  String get hrLow => 'Low — check if resting';

  @override
  String get hrSafe => 'Safe Range';

  @override
  String get hrSlightlyElevated => 'Slightly elevated';

  @override
  String get hrElevated => 'Elevated — monitor';

  @override
  String get spo2Normal => 'Normal';

  @override
  String get spo2Monitor => 'Monitor Closely';

  @override
  String get spo2Low => 'Low — seek help';

  @override
  String get postMedicationImpact => 'Post-Medication Impact';

  @override
  String get trackingHrTrends => 'Tracking heart rate trends after medication';

  @override
  String trackingForLogId(String id) {
    return 'Tracking for log ID: $id';
  }

  @override
  String get sendEmergencyAlert => 'Send Emergency Alert';

  @override
  String get emergencyAlertSubtitle =>
      'Tap if you feel unwell — sends iMessage & offers to call your emergency contacts';

  @override
  String get callForHelp => 'Call for Help?';

  @override
  String callConfirmMessage(String name) {
    return 'Do you want to call $name?';
  }

  @override
  String get no => 'No';

  @override
  String get yesCallNow => 'Yes, Call Now';

  @override
  String get emergencyAlertSent => 'Emergency alert sent!';

  @override
  String get medicationDetails => 'Medication details';

  @override
  String get reviewAndEdit =>
      'Review and edit fields from your scan before saving';

  @override
  String get drugReferenceLoaded =>
      'Drug reference loaded. It will be stored with this medication when you save';

  @override
  String get medicineName => 'Medicine name';

  @override
  String get medicineNameHint => 'e.g. Metformin';

  @override
  String get chineseNameOptional => 'Chinese name (optional)';

  @override
  String get dosage => 'Dosage';

  @override
  String get dosageHint => 'e.g. 500mg';

  @override
  String get schedule => 'Schedule';

  @override
  String get change => 'Change';

  @override
  String get addAnotherTime => 'Add another time';

  @override
  String get daysOfWeek => 'Days of week';

  @override
  String get everyDay => '(every day)';

  @override
  String get tapDayToToggle =>
      'Tap a day to toggle. Tap all to reset to every day';

  @override
  String get descriptionOptional => 'Description (optional)';

  @override
  String get descriptionHint => 'Notes, instructions, or OCR context...';

  @override
  String get saveMedication => 'Save medication';

  @override
  String get cancel => 'Cancel';

  @override
  String get scanMedication => 'Scan Medication';

  @override
  String get tapToScan =>
      'Tap the camera button to scan a prescription or medication label';

  @override
  String get processing => 'Processing...';

  @override
  String get retake => 'Retake';

  @override
  String get useLiveCamera => 'Use Live Camera';

  @override
  String get pickFromGallery => 'Pick from Gallery';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmIntake => 'Confirm Intake';

  @override
  String get notDueYet => 'Not due yet';

  @override
  String get monitoringActive => 'Monitoring Active';

  @override
  String monitoringEndsIn(String time) {
    return 'Monitoring ends in $time';
  }

  @override
  String get stopMonitoring => 'Stop Monitoring';

  @override
  String get startMonitoring => 'Start Monitoring';

  @override
  String get relationSon => 'Son';

  @override
  String get relationDaughter => 'Daughter';

  @override
  String get relationSpouse => 'Spouse';

  @override
  String get relationParent => 'Parent';

  @override
  String get relationSibling => 'Sibling';

  @override
  String get relationDoctor => 'Doctor';

  @override
  String get relationCaregiver => 'Caregiver';

  @override
  String get relationFriend => 'Friend';
}
