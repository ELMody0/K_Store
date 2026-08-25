import 'package:url_launcher/url_launcher.dart';
import 'app_update_service.dart';

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

  /// بيفتح رابط التحميل في المتصفح/مدير الملفات.
  Future<void> openUpdate() async {
    final url = info?.apkUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
