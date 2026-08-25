import 'package:url_launcher/url_launcher.dart';

/// بيحوّل رابط تحميل APK المباشر لـ رابط صفحة الـ release على GitHub.
///
/// ليه؟ لأن Android (خاصة 11+) بيمنع فتح روابط الملفات المباشرة
/// من تطبيق تالت، فيرجع "component name is null". صفحة الـ release
/// بتتفتح في المتصفح ضمان 100%، والمستخدم يقدر يحمّل من هناك.
String toReleasePageUrl(String apkUrl) {
  // مثال: https://github.com/OWNER/REPO/releases/download/v1.0.1/app-release.apk
  final re = RegExp(r'github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/');
  final m = re.firstMatch(apkUrl);
  if (m != null) {
    final owner = m.group(1)!;
    final repo = m.group(2)!;
    final tag = m.group(3)!;
    return 'https://github.com/$owner/$repo/releases/tag/$tag';
  }
  return apkUrl; // لو مش GitHub release، نرجّع زي ما هو
}

/// يفتح رابط التحديث في المتصفح بأمان.
Future<void> launchUpdateUrl(String apkUrl) async {
  final safeUrl = toReleasePageUrl(apkUrl);
  final uri = Uri.parse(safeUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
