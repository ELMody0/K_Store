import 'app_update_service.dart';
import 'update_launcher.dart';

/// خدمة مركزية لفحص تحديثات التطبيق.
///
/// بتتعمل مرة واحدة عند فتح الأبلكيشن (في SplashPage)، وبتتخزن النتيجة
/// عشان صفحة "تحديثات التطبيق" تقرأها من غير ما تعيد الفحص.
class UpdateChecker {
  UpdateChecker._();
  static final UpdateChecker instance = UpdateChecker._();

  final AppUpdateService _service = AppUpdateService(
    bucket: 'updates',
    jsonPath: 'update.json',
  );

  SupabaseUpdateInfo? info;
  bool _checked = false;

  /// يفحص التحديث مرة واحدة بس. لو اتعملت تاني بترجّع النتيجة المحفوظة.
  Future<SupabaseUpdateInfo?> check() async {
    if (_checked) return info;
    _checked = true;
    try {
      info = await _service.checkForUpdate();
    } catch (_) {
      info = null;
    }
    return info;
  }

  bool get hasUpdate => info?.isNewer == true;

  /// بيفتح رابط التحميل (صفحة الـ release) في المتصفح بأمان.
  Future<void> openUpdate() async {
    final url = info?.apkUrl;
    if (url == null) return;
    await launchUpdateUrl(url);
  }
}
