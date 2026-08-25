import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة فحص تحديثات التطبيق من Supabase Storage.
///
/// الفكرة: إنت ترفع ملف `update.json` + ملف APK على Supabase Storage (bucket عام)،
/// والتطبيق يقارن رقم الإصدار الموجود في الـ json برقم تطبيق المستخدم.
/// لو فيه إصدار أحدث → بيرجّع رابط التحميل.
///
/// محتوى ملف update.json المرفوع على Storage:
/// {
///   "version": "1.0.1",
///   "apk_path": "app-release.apk",   // اسم الملف جوه نفس الـ bucket
///   "title": "تحديث الأداء",
///   "notes": "تحسينات في السرعة وإصلاح الأخطاء"
/// }
class AppUpdateService {
  AppUpdateService({
    required this.bucket,
    this.jsonPath = 'update.json',
  });

  final String bucket;
  final String jsonPath;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const _timeout = Duration(seconds: 12);

  /// يقرأ ملف update.json من الـ Storage ويقارن بالإصدار الحالي.
  /// يرجع null لو حصل خطأ أو مفيش نت.
  Future<SupabaseUpdateInfo?> checkForUpdate() async {
    try {
      final data = await _supabase.storage
          .from(bucket)
          .download(jsonPath)
          .timeout(_timeout);

      final text = utf8.decode(data);
      final map = jsonDecode(text) as Map<String, dynamic>;

      final remoteVersion = (map['version'] as String? ?? '').trim();
      if (remoteVersion.isEmpty) return null;

      final current = await _currentVersion();
      final isNewer = _isNewer(remoteVersion, current);

      // رابط التحميل: إما apk_url مباشر، أو نبني من مسار داخل الـ bucket
      String? apkUrl = map['apk_url'] as String?;
      if ((apkUrl == null || apkUrl.isEmpty) && map['apk_path'] != null) {
        apkUrl = _supabase.storage.from(bucket).getPublicUrl(map['apk_path'] as String);
      }

      return SupabaseUpdateInfo(
        version: remoteVersion,
        isNewer: isNewer,
        apkUrl: apkUrl,
        title: map['title'] as String?,
        notes: map['notes'] as String?,
      );
    } catch (e) {
      debugPrint('AppUpdateService error: $e');
      return null;
    }
  }

  Future<String> _currentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '0.0.0';
    }
  }

  /// يقارن رقمين إصدار: "1.2.0" vs "1.1.5"
  /// يرجع true لو [remote] أحدث من [current].
  bool _isNewer(String remote, String current) {
    final r = _normalize(remote);
    final c = _normalize(current);

    final rp = r.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final cp = c.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final len = rp.length > cp.length ? rp.length : cp.length;
    while (rp.length < len) {
      rp.add(0);
    }
    while (cp.length < len) {
      cp.add(0);
    }

    for (var i = 0; i < len; i++) {
      if (rp[i] > cp[i]) return true;
      if (rp[i] < cp[i]) return false;
    }
    return false; // متساويين
  }

  String _normalize(String v) {
    var s = v.trim().toLowerCase();
    if (s.startsWith('v')) s = s.substring(1);
    final plus = s.indexOf('+');
    if (plus != -1) s = s.substring(0, plus);
    final dash = s.indexOf('-');
    if (dash != -1) s = s.substring(0, dash);
    final parts = s.split('.');
    while (parts.length < 3) {
      parts.add('0');
    }
    return parts.take(3).join('.');
  }
}

class SupabaseUpdateInfo {
  const SupabaseUpdateInfo({
    required this.version,
    required this.isNewer,
    this.apkUrl,
    this.title,
    this.notes,
  });

  final String version;
  final bool isNewer;
  final String? apkUrl;
  final String? title;
  final String? notes;
}
