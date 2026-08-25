import 'package:url_launcher/url_launcher.dart';

/// يفتح رابط التحميل المباشر للـ APK في المتصفح/مدير الملفات.
///
/// على التلفون الحقيقي رابط APK المباشر بيتحمّل أوتوماتيك
/// (المشكلة السابقة were من الـ emulator فقط).
Future<void> launchUpdateUrl(String apkUrl) async {
  final uri = Uri.parse(apkUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
