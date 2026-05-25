import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MediAgent'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get navScan;

  /// No description provided for @navHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get navHealth;

  /// No description provided for @navCompliance.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navCompliance;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @todaysMedications.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Medications'**
  String get todaysMedications;

  /// No description provided for @dosesToday.
  ///
  /// In en, this message translates to:
  /// **'{count} dose(s) today'**
  String dosesToday(int count);

  /// No description provided for @noMedicationsAdded.
  ///
  /// In en, this message translates to:
  /// **'No medications added yet'**
  String get noMedicationsAdded;

  /// No description provided for @viewFullSchedule.
  ///
  /// In en, this message translates to:
  /// **'View Full Schedule'**
  String get viewFullSchedule;

  /// No description provided for @healthMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Health Monitoring'**
  String get healthMonitoring;

  /// No description provided for @heartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get heartRate;

  /// No description provided for @bloodOxygen.
  ///
  /// In en, this message translates to:
  /// **'Blood O₂'**
  String get bloodOxygen;

  /// No description provided for @liveFromAppleWatch.
  ///
  /// In en, this message translates to:
  /// **'Live from Apple Watch'**
  String get liveFromAppleWatch;

  /// No description provided for @fromIPhone.
  ///
  /// In en, this message translates to:
  /// **'From iPhone'**
  String get fromIPhone;

  /// No description provided for @lastReadingShown.
  ///
  /// In en, this message translates to:
  /// **'Last reading shown'**
  String get lastReadingShown;

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet — confirm a dose to start'**
  String get noDataYet;

  /// No description provided for @weeklyReport.
  ///
  /// In en, this message translates to:
  /// **'Weekly Report'**
  String get weeklyReport;

  /// No description provided for @medicationAdherence.
  ///
  /// In en, this message translates to:
  /// **'Medication adherence'**
  String get medicationAdherence;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @noContactsAdded.
  ///
  /// In en, this message translates to:
  /// **'No contacts added yet'**
  String get noContactsAdded;

  /// No description provided for @emergencyAlerts.
  ///
  /// In en, this message translates to:
  /// **'Emergency Alerts'**
  String get emergencyAlerts;

  /// No description provided for @healthMonitor.
  ///
  /// In en, this message translates to:
  /// **'Health Monitor'**
  String get healthMonitor;

  /// No description provided for @medicationLogId.
  ///
  /// In en, this message translates to:
  /// **'Medication Log ID'**
  String get medicationLogId;

  /// No description provided for @enterLogId.
  ///
  /// In en, this message translates to:
  /// **'Enter log_id from taken medication flow'**
  String get enterLogId;

  /// No description provided for @bpm.
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get bpm;

  /// No description provided for @safe.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get safe;

  /// No description provided for @hrLow.
  ///
  /// In en, this message translates to:
  /// **'Low — check if resting'**
  String get hrLow;

  /// No description provided for @hrSafe.
  ///
  /// In en, this message translates to:
  /// **'Safe Range'**
  String get hrSafe;

  /// No description provided for @hrSlightlyElevated.
  ///
  /// In en, this message translates to:
  /// **'Slightly elevated'**
  String get hrSlightlyElevated;

  /// No description provided for @hrElevated.
  ///
  /// In en, this message translates to:
  /// **'Elevated — monitor'**
  String get hrElevated;

  /// No description provided for @spo2Normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get spo2Normal;

  /// No description provided for @spo2Monitor.
  ///
  /// In en, this message translates to:
  /// **'Monitor Closely'**
  String get spo2Monitor;

  /// No description provided for @spo2Low.
  ///
  /// In en, this message translates to:
  /// **'Low — seek help'**
  String get spo2Low;

  /// No description provided for @postMedicationImpact.
  ///
  /// In en, this message translates to:
  /// **'Post-Medication Impact'**
  String get postMedicationImpact;

  /// No description provided for @trackingHrTrends.
  ///
  /// In en, this message translates to:
  /// **'Tracking heart rate trends after medication'**
  String get trackingHrTrends;

  /// No description provided for @trackingForLogId.
  ///
  /// In en, this message translates to:
  /// **'Tracking for log ID: {id}'**
  String trackingForLogId(String id);

  /// No description provided for @sendEmergencyAlert.
  ///
  /// In en, this message translates to:
  /// **'Send Emergency Alert'**
  String get sendEmergencyAlert;

  /// No description provided for @emergencyAlertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap if you feel unwell — sends iMessage & offers to call your emergency contacts'**
  String get emergencyAlertSubtitle;

  /// No description provided for @callForHelp.
  ///
  /// In en, this message translates to:
  /// **'Call for Help?'**
  String get callForHelp;

  /// No description provided for @callConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to call {name}?'**
  String callConfirmMessage(String name);

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yesCallNow.
  ///
  /// In en, this message translates to:
  /// **'Yes, Call Now'**
  String get yesCallNow;

  /// No description provided for @emergencyAlertSent.
  ///
  /// In en, this message translates to:
  /// **'Emergency alert sent!'**
  String get emergencyAlertSent;

  /// No description provided for @medicationDetails.
  ///
  /// In en, this message translates to:
  /// **'Medication details'**
  String get medicationDetails;

  /// No description provided for @reviewAndEdit.
  ///
  /// In en, this message translates to:
  /// **'Review and edit fields from your scan before saving'**
  String get reviewAndEdit;

  /// No description provided for @drugReferenceLoaded.
  ///
  /// In en, this message translates to:
  /// **'Drug reference loaded. It will be stored with this medication when you save'**
  String get drugReferenceLoaded;

  /// No description provided for @medicineName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get medicineName;

  /// No description provided for @medicineNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Metformin'**
  String get medicineNameHint;

  /// No description provided for @chineseNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Chinese name (optional)'**
  String get chineseNameOptional;

  /// No description provided for @dosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get dosage;

  /// No description provided for @dosageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 500mg'**
  String get dosageHint;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @addAnotherTime.
  ///
  /// In en, this message translates to:
  /// **'Add another time'**
  String get addAnotherTime;

  /// No description provided for @daysOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Days of week'**
  String get daysOfWeek;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'(every day)'**
  String get everyDay;

  /// No description provided for @tapDayToToggle.
  ///
  /// In en, this message translates to:
  /// **'Tap a day to toggle. Tap all to reset to every day'**
  String get tapDayToToggle;

  /// No description provided for @descriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get descriptionOptional;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Notes, instructions, or OCR context...'**
  String get descriptionHint;

  /// No description provided for @saveMedication.
  ///
  /// In en, this message translates to:
  /// **'Save medication'**
  String get saveMedication;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @scanMedication.
  ///
  /// In en, this message translates to:
  /// **'Scan Medication'**
  String get scanMedication;

  /// No description provided for @tapToScan.
  ///
  /// In en, this message translates to:
  /// **'Tap the camera button to scan a prescription or medication label'**
  String get tapToScan;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @useLiveCamera.
  ///
  /// In en, this message translates to:
  /// **'Use Live Camera'**
  String get useLiveCamera;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from Gallery'**
  String get pickFromGallery;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmIntake.
  ///
  /// In en, this message translates to:
  /// **'Confirm Intake'**
  String get confirmIntake;

  /// No description provided for @notDueYet.
  ///
  /// In en, this message translates to:
  /// **'Not due yet'**
  String get notDueYet;

  /// No description provided for @monitoringActive.
  ///
  /// In en, this message translates to:
  /// **'Monitoring Active'**
  String get monitoringActive;

  /// No description provided for @monitoringEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Monitoring ends in {time}'**
  String monitoringEndsIn(String time);

  /// No description provided for @stopMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Stop Monitoring'**
  String get stopMonitoring;

  /// No description provided for @startMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Start Monitoring'**
  String get startMonitoring;

  /// No description provided for @relationSon.
  ///
  /// In en, this message translates to:
  /// **'Son'**
  String get relationSon;

  /// No description provided for @relationDaughter.
  ///
  /// In en, this message translates to:
  /// **'Daughter'**
  String get relationDaughter;

  /// No description provided for @relationSpouse.
  ///
  /// In en, this message translates to:
  /// **'Spouse'**
  String get relationSpouse;

  /// No description provided for @relationParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get relationParent;

  /// No description provided for @relationSibling.
  ///
  /// In en, this message translates to:
  /// **'Sibling'**
  String get relationSibling;

  /// No description provided for @relationDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get relationDoctor;

  /// No description provided for @relationCaregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get relationCaregiver;

  /// No description provided for @relationFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get relationFriend;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
