// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '藥衛士';

  @override
  String get navHome => '首頁';

  @override
  String get navScan => '掃描';

  @override
  String get navHealth => '健康';

  @override
  String get navCompliance => '報告';

  @override
  String get navProfile => '個人';

  @override
  String get todaysMedications => '今日用藥';

  @override
  String dosesToday(int count) {
    return '今日 $count 次';
  }

  @override
  String get noMedicationsAdded => '尚未新增藥物';

  @override
  String get viewFullSchedule => '查看完整時程';

  @override
  String get healthMonitoring => '健康監測';

  @override
  String get heartRate => '心率';

  @override
  String get bloodOxygen => '血氧';

  @override
  String get liveFromAppleWatch => '來自 Apple Watch';

  @override
  String get fromIPhone => '來自 iPhone';

  @override
  String get lastReadingShown => '顯示最近讀數';

  @override
  String get noDataYet => '尚無資料 — 確認服藥後開始監測';

  @override
  String get weeklyReport => '週報告';

  @override
  String get medicationAdherence => '服藥遵從率';

  @override
  String get emergency => '緊急聯絡';

  @override
  String get noContactsAdded => '尚未新增聯絡人';

  @override
  String get emergencyAlerts => '緊急警報';

  @override
  String get healthMonitor => '健康監測';

  @override
  String get medicationLogId => '用藥記錄 ID';

  @override
  String get enterLogId => '輸入服藥流程中的 log_id';

  @override
  String get bpm => '次/分';

  @override
  String get safe => '正常';

  @override
  String get hrLow => '偏低 — 請確認是否休息中';

  @override
  String get hrSafe => '正常範圍';

  @override
  String get hrSlightlyElevated => '略偏高';

  @override
  String get hrElevated => '偏高 — 請持續觀察';

  @override
  String get spo2Normal => '正常';

  @override
  String get spo2Monitor => '需注意';

  @override
  String get spo2Low => '偏低 — 請立即就醫';

  @override
  String get postMedicationImpact => '服藥後健康趨勢';

  @override
  String get trackingHrTrends => '持續追蹤服藥後心率變化';

  @override
  String trackingForLogId(String id) {
    return '追蹤記錄 ID：$id';
  }

  @override
  String get sendEmergencyAlert => '發送緊急警報';

  @override
  String get emergencyAlertSubtitle => '感覺不適時點擊 — 傳送 iMessage 並提供致電選項';

  @override
  String get callForHelp => '需要協助嗎？';

  @override
  String callConfirmMessage(String name) {
    return '您要致電 $name 嗎？';
  }

  @override
  String get no => '否';

  @override
  String get yesCallNow => '是，立即撥打';

  @override
  String get emergencyAlertSent => '緊急警報已發送！';

  @override
  String get medicationDetails => '藥物資訊';

  @override
  String get reviewAndEdit => '請確認並編輯掃描結果後儲存';

  @override
  String get drugReferenceLoaded => '藥物資料已載入，儲存時將一併儲存';

  @override
  String get medicineName => '藥物名稱';

  @override
  String get medicineNameHint => '例：Metformin';

  @override
  String get chineseNameOptional => '中文名稱（選填）';

  @override
  String get dosage => '劑量';

  @override
  String get dosageHint => '例：500mg';

  @override
  String get schedule => '時程';

  @override
  String get change => '更改';

  @override
  String get addAnotherTime => '新增時間';

  @override
  String get daysOfWeek => '服藥日';

  @override
  String get everyDay => '（每天）';

  @override
  String get tapDayToToggle => '點擊日期切換，點擊全部重設為每天';

  @override
  String get descriptionOptional => '備註（選填）';

  @override
  String get descriptionHint => '備註、說明或 OCR 辨識內容...';

  @override
  String get saveMedication => '儲存藥物';

  @override
  String get cancel => '取消';

  @override
  String get scanMedication => '掃描藥物';

  @override
  String get tapToScan => '點擊相機按鈕掃描處方箋或藥物標籤';

  @override
  String get processing => '處理中...';

  @override
  String get retake => '重拍';

  @override
  String get useLiveCamera => '使用即時相機';

  @override
  String get pickFromGallery => '從相簿選取';

  @override
  String get confirm => '確認';

  @override
  String get confirmIntake => '確認服藥';

  @override
  String get notDueYet => '尚未到服藥時間';

  @override
  String get monitoringActive => '監測進行中';

  @override
  String monitoringEndsIn(String time) {
    return '監測將於 $time 結束';
  }

  @override
  String get stopMonitoring => '停止監測';

  @override
  String get startMonitoring => '開始監測';

  @override
  String get relationSon => '兒子';

  @override
  String get relationDaughter => '女兒';

  @override
  String get relationSpouse => '配偶';

  @override
  String get relationParent => '父母';

  @override
  String get relationSibling => '兄弟姐妹';

  @override
  String get relationDoctor => '醫生';

  @override
  String get relationCaregiver => '看護';

  @override
  String get relationFriend => '朋友';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appName => '藥衛士';

  @override
  String get navHome => '首頁';

  @override
  String get navScan => '掃描';

  @override
  String get navHealth => '健康';

  @override
  String get navCompliance => '報告';

  @override
  String get navProfile => '個人';

  @override
  String get todaysMedications => '今日用藥';

  @override
  String dosesToday(int count) {
    return '今日 $count 次';
  }

  @override
  String get noMedicationsAdded => '尚未新增藥物';

  @override
  String get viewFullSchedule => '查看完整時程';

  @override
  String get healthMonitoring => '健康監測';

  @override
  String get heartRate => '心率';

  @override
  String get bloodOxygen => '血氧';

  @override
  String get liveFromAppleWatch => '來自 Apple Watch';

  @override
  String get fromIPhone => '來自 iPhone';

  @override
  String get lastReadingShown => '顯示最近讀數';

  @override
  String get noDataYet => '尚無資料 — 確認服藥後開始監測';

  @override
  String get weeklyReport => '週報告';

  @override
  String get medicationAdherence => '服藥遵從率';

  @override
  String get emergency => '緊急聯絡';

  @override
  String get noContactsAdded => '尚未新增聯絡人';

  @override
  String get emergencyAlerts => '緊急警報';

  @override
  String get healthMonitor => '健康監測';

  @override
  String get medicationLogId => '用藥記錄 ID';

  @override
  String get enterLogId => '輸入服藥流程中的 log_id';

  @override
  String get bpm => '次/分';

  @override
  String get safe => '正常';

  @override
  String get hrLow => '偏低 — 請確認是否休息中';

  @override
  String get hrSafe => '正常範圍';

  @override
  String get hrSlightlyElevated => '略偏高';

  @override
  String get hrElevated => '偏高 — 請持續觀察';

  @override
  String get spo2Normal => '正常';

  @override
  String get spo2Monitor => '需注意';

  @override
  String get spo2Low => '偏低 — 請立即就醫';

  @override
  String get postMedicationImpact => '服藥後健康趨勢';

  @override
  String get trackingHrTrends => '持續追蹤服藥後心率變化';

  @override
  String trackingForLogId(String id) {
    return '追蹤記錄 ID：$id';
  }

  @override
  String get sendEmergencyAlert => '發送緊急警報';

  @override
  String get emergencyAlertSubtitle => '感覺不適時點擊 — 傳送 iMessage 並提供致電選項';

  @override
  String get callForHelp => '需要協助嗎？';

  @override
  String callConfirmMessage(String name) {
    return '您要致電 $name 嗎？';
  }

  @override
  String get no => '否';

  @override
  String get yesCallNow => '是，立即撥打';

  @override
  String get emergencyAlertSent => '緊急警報已發送！';

  @override
  String get medicationDetails => '藥物資訊';

  @override
  String get reviewAndEdit => '請確認並編輯掃描結果後儲存';

  @override
  String get drugReferenceLoaded => '藥物資料已載入，儲存時將一併儲存';

  @override
  String get medicineName => '藥物名稱';

  @override
  String get medicineNameHint => '例：Metformin';

  @override
  String get chineseNameOptional => '中文名稱（選填）';

  @override
  String get dosage => '劑量';

  @override
  String get dosageHint => '例：500mg';

  @override
  String get schedule => '時程';

  @override
  String get change => '更改';

  @override
  String get addAnotherTime => '新增時間';

  @override
  String get daysOfWeek => '服藥日';

  @override
  String get everyDay => '（每天）';

  @override
  String get tapDayToToggle => '點擊日期切換，點擊全部重設為每天';

  @override
  String get descriptionOptional => '備註（選填）';

  @override
  String get descriptionHint => '備註、說明或 OCR 辨識內容...';

  @override
  String get saveMedication => '儲存藥物';

  @override
  String get cancel => '取消';

  @override
  String get scanMedication => '掃描藥物';

  @override
  String get tapToScan => '點擊相機按鈕掃描處方箋或藥物標籤';

  @override
  String get processing => '處理中...';

  @override
  String get retake => '重拍';

  @override
  String get useLiveCamera => '使用即時相機';

  @override
  String get pickFromGallery => '從相簿選取';

  @override
  String get confirm => '確認';

  @override
  String get confirmIntake => '確認服藥';

  @override
  String get notDueYet => '尚未到服藥時間';

  @override
  String get monitoringActive => '監測進行中';

  @override
  String monitoringEndsIn(String time) {
    return '監測將於 $time 結束';
  }

  @override
  String get stopMonitoring => '停止監測';

  @override
  String get startMonitoring => '開始監測';

  @override
  String get relationSon => '兒子';

  @override
  String get relationDaughter => '女兒';

  @override
  String get relationSpouse => '配偶';

  @override
  String get relationParent => '父母';

  @override
  String get relationSibling => '兄弟姐妹';

  @override
  String get relationDoctor => '醫生';

  @override
  String get relationCaregiver => '看護';

  @override
  String get relationFriend => '朋友';
}
