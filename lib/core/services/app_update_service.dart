import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// خدمة فحص تحديثات التطبيق من GitHub Releases.
///
/// الفكرة: إنت ترفع APK جديد على GitHub Release برقم إصدار أكبر
/// (مثال: v1.2.0)، والسيرفس يقارنه برقم تطبيق المستخدم.
/// لو فيه إصدار أحدث → بيرجّع رابط التحميل.
class AppUpdateService {
  AppUpdateService({
    required this.owner,
    required this.repo,
    this.includePreReleases = false,
  });

  final String owner;
  final String repo;
  final bool includePreReleases;

  static const _timeout = Duration(seconds: 12);

  /// بيفحص أحدث إصدار متاح على GitHub Releases.
  /// يرجع null لو حصل خطأ أو مفيش نت.
  Future<GitHubReleaseInfo?> checkForUpdate() async {
    try {
      final url = Uri.https(
        'api.github.com',
        '/repos/$owner/$repo/releases',
        includePreReleases ? null : {'per_page': '20'},
      );
      final res = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(_timeout);

      if (res.statusCode != 200) return null;

      final List<dynamic> releases = jsonDecode(res.body) as List<dynamic>;
      if (releases.isEmpty) return null;

      // نفلتر الـ drafts والـ pre-releases (لو مش عايزينها)
      final valid = releases.where((r) {
        final map = r as Map<String, dynamic>;
        if (map['draft'] == true) return false;
        if (!includePreReleases && map['prerelease'] == true) return false;
        return true;
      }).toList();

      if (valid.isEmpty) return null;

      // نختار أول واحد (GitHub بيرجّعهم الأحدث أولاً)
      final latest = valid.first as Map<String, dynamic>;
      final tag = (latest['tag_name'] as String? ?? '').trim();
      if (tag.isEmpty) return null;

      final current = await _currentVersion();
      final isNewer = _isNewer(tag, current);

      // ندوّر على أول asset من امتداد apk
      String? apkUrl;
      final assets = latest['assets'] as List<dynamic>? ?? [];
      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String?;
          break;
        }
      }

      return GitHubReleaseInfo(
        tagName: tag,
        isNewer: isNewer,
        apkUrl: apkUrl,
        htmlUrl: latest['html_url'] as String?,
        name: latest['name'] as String?,
        body: latest['body'] as String?,
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

  /// يقارن رقمين إصدار: "v1.2.0" vs "1.1.5"
  /// يرجع true لو [remoteTag] أحدث من [current].
  bool _isNewer(String remoteTag, String current) {
    final r = _normalize(remoteTag);
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
    // نشيل أي لاحقة زي +build أو -beta
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

class GitHubReleaseInfo {
  const GitHubReleaseInfo({
    required this.tagName,
    required this.isNewer,
    this.apkUrl,
    this.htmlUrl,
    this.name,
    this.body,
  });

  final String tagName;
  final bool isNewer;
  final String? apkUrl;
  final String? htmlUrl;
  final String? name;
  final String? body;
}
