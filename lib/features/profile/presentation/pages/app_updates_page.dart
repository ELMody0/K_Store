import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/services/update_checker.dart';
import 'package:k_store/core/services/update_launcher.dart';

class AppUpdatesPage extends StatefulWidget {
  const AppUpdatesPage({super.key});

  @override
  State<AppUpdatesPage> createState() => _AppUpdatesPageState();
}

class _AppUpdatesPageState extends State<AppUpdatesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // نستخدم خدمة الفحص المركزية (اتعملت مرة واحدة في SplashPage)
  bool _checkingUpdate = false;

  bool _isOwner = false;
  List<Map<String, dynamic>> _updates = [];
  bool _hasData = false;
  bool _loading = true;
  Object? _error;
  bool _showError = false;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  Timer? _errorTimer;
  String? _expandedId;

  // يرجّع رقم إصدار الأبلكيشن الحالي (مثل 1.0.4) عشان يتكتب في التحديث
  Future<String> _currentVersionString() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeStream();
    _checkRole();
    // لو الفحص لسه ما اتعملش (المستخدم فتح الصفحة مباشرة من غير Splash) نفحص
    _checkForAppUpdate();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final res = await _supabase.from('app_updates').select().order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _updates = List<Map<String, dynamic>>.from(res as List);
        _hasData = true;
        _loading = false;
        _error = null;
        _showError = false;
        if (_updates.isNotEmpty) _expandedId ??= _updates.first['id']?.toString();
      });
    } catch (e) {
      if (!mounted) return;
      if (_hasData) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
      _errorTimer?.cancel();
      _errorTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && !_hasData && _error != null) setState(() => _showError = true);
      });
    }
  }

  void _subscribeStream() {
    _sub?.cancel();
    final stream = _supabase.from('app_updates').stream(primaryKey: ['id']).order('created_at', ascending: false);
    _sub = stream.listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _updates = data;
          _hasData = true;
          _loading = false;
          _error = null;
          _showError = false;
          if (_updates.isNotEmpty) _expandedId ??= _updates.first['id']?.toString();
        });
      },
      onError: (_) {},
    );
  }

  Future<void> _checkRole() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await _supabase.from('profiles').select('role').eq('id', uid).maybeSingle();
      if (mounted) setState(() => _isOwner = data?['role']?.toString().toLowerCase() == 'owner');
    } catch (_) {}
  }

  Future<void> _checkForAppUpdate() async {
    if (_checkingUpdate) return;
    // لو الفحص اتعمل من SplashPage خلاص، نعكس النتيجة بس
    if (UpdateChecker.instance.info != null) {
      if (mounted) setState(() {});
      return;
    }
    setState(() => _checkingUpdate = true);
    try {
      await UpdateChecker.instance.check();
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _deleteUpdate(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkGrey : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف التحديث', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text(
          'هل أنت متأكد من حذف هذا التحديث نهائياً؟',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('حذف', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _supabase.from('app_updates').delete().eq('id', id);
        _load(showLoading: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('تم حذف التحديث'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر الحذف: $e')));
      }
    }
  }

  Future<void> _showForm({Map<String, dynamic>? existing}) async {
    final titleC = TextEditingController(text: existing?['title'] ?? '');
    final bodyC = TextEditingController(text: existing?['body'] ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16171A).withValues(alpha: 0.97) : Colors.white.withValues(alpha: 0.97),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
              ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 20),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        existing == null ? 'إضافة تحديث جديد' : 'تعديل التحديث',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: titleC,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'من فضلك اكتب عنوان التحديث' : null,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'العنوان أو اسم الإصدار *',
                          labelStyle: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13),
                          hintText: 'مثال: تحديث الأداء والإشعارات',
                          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 13),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: textColor, width: 1.2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: bodyC,
                        maxLines: 5,
                        style: TextStyle(color: textColor, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'نص التحديث / التفاصيل',
                          labelStyle: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 13),
                          hintText: 'اكتب نص التحديث بالتفصيل هنا...',
                          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 13),
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: textColor, width: 1.2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!(formKey.currentState?.validate() ?? false)) return;
                            Navigator.pop(ctx, true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white : Colors.black,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(
                            existing == null ? 'نشر التحديث' : 'حفظ التعديلات',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    if (result != true) return;
    final title = titleC.text.trim();
    final body = bodyC.text.trim();
    if (title.isEmpty) return;
    try {
      if (existing == null) {
        await _supabase.from('app_updates').insert({'title': title, 'body': body, 'version': _currentVersionString(), 'created_by': _supabase.auth.currentUser?.id});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('✅ تم نشر التحديث'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          );
        }
      } else {
        await _supabase.from('app_updates').update({'title': title, 'body': body, 'updated_at': DateTime.now().toIso8601String()}).eq('id', existing['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('✅ تم حفظ التعديلات'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          );
        }
      }
      _load(showLoading: false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر الحفظ: $e')));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _errorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: FadeInDown(
          duration: const Duration(milliseconds: 500),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.system_update_alt_rounded, size: 20, color: textColor.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                'تحديثات التطبيق',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: 0.3, color: textColor),
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: const [],
      ),
      body: WavyBackground(child: _buildBody()),
      floatingActionButton: _isOwner
          ? Padding(
              padding: const EdgeInsets.only(bottom: 112, right: 8),
              child: FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: FloatingActionButton.extended(
                  onPressed: () => _showForm(),
                  backgroundColor: isDark ? const Color(0xFF1E2024) : Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black12,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'إضافة تحديث',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    if (_showError && _error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 52, color: textColor.withValues(alpha: 0.3)),
              const SizedBox(height: 20),
              const Text('تعذّر تحميل التحديثات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                'تأكد من الاتصال بالإنترنت وحاول مجدداً.',
                style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: textColor.withValues(alpha: 0.4), strokeWidth: 2.5),
      );
    }

    if (_updates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.rss_feed_rounded, size: 46, color: textColor.withValues(alpha: 0.25)),
            ),
            const SizedBox(height: 18),
            Text(
              'لا توجد تحديثات حالياً',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: textColor.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 6),
            Text(
              'ستظهر هنا كل جديد التطبيق أول بأول',
              style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.4)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(showLoading: false),
      color: textColor,
      backgroundColor: isDark ? const Color(0xFF1E2024) : Colors.white,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 115, 20, 170),
        itemCount: _updates.length,
        itemBuilder: (context, i) {
          final u = _updates[i];
          final isLatest = i == 0;
          return FadeInUp(
            delay: Duration(milliseconds: i * 80),
            duration: const Duration(milliseconds: 550),
            from: 20,
            child: _buildUpdateCard(u, isLatest: isLatest, isDark: isDark, textColor: textColor),
          );
        },
      ),
    );
  }

  Widget _buildUpdateCard(
    Map<String, dynamic> u, {
    required bool isLatest,
    required bool isDark,
    required Color textColor,
  }) {
    final bodyText = (u['body'] ?? '').toString().trim();
    final id = u['id']?.toString();
    final expanded = _expandedId == id || bodyText.length < 160;
    final needsTruncate = bodyText.length >= 160;
    final displayBody = expanded || !needsTruncate
        ? bodyText
        : '${bodyText.substring(0, 155).trim()}...';

    final iconColor = isDark ? Colors.white70 : const Color(0xFF1A1A1A);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C20) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.white,
          width: isLatest ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== الهيدر: أيقونة + العنوان + شارة الأحدث =====
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF2F2F2),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.white,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // أيقونة الإصدار (بدون بوكس — سيمبل)
                  Icon(
                    isLatest ? Icons.segment_rounded : Icons.notes_rounded,
                    size: 24,
                    color: isLatest ? iconColor : iconColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 12),
                  // العنوان: نعرض رقم الإصدار (الأهم للمستخدم) وإلا العنوان المحفوظ
                  Expanded(
                    child: Text(
                      (u['version'] ?? '').toString().isNotEmpty
                          ? 'تحديث ${u['version']}'
                          : (u['title'] ?? ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (isLatest)
                    Container(
                      margin: const EdgeInsetsDirectional.only(start: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.new_releases_rounded, size: 12, color: isDark ? Colors.white : Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            'الأحدث',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.white),
                          ),
                        ],
                      ),
                    ),
                  // أزرار المالك
                  if (_isOwner) ...[
                    const SizedBox(width: 6),
                    _ownerAction(
                      context,
                      icon: Icons.edit_outlined,
                      tooltip: 'تعديل',
                      color: textColor.withValues(alpha: 0.45),
                      onTap: () => _showForm(existing: u),
                    ),
                    const SizedBox(width: 4),
                    _ownerAction(
                      context,
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'حذف',
                      color: Colors.redAccent,
                      onTap: () => _deleteUpdate(u['id']),
                    ),
                  ],
                ],
              ),
            ),

            // ===== نص التحديث =====
            if (bodyText.isNotEmpty && bodyText != (u['title'] ?? ''))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(
                  displayBody,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.75,
                    color: isDark ? const Color(0xFFCDD0D5) : const Color(0xFF3A3D42),
                  ),
                ),
              ),

            // زر قراءة المزيد / أقل
            if (needsTruncate)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => setState(() => _expandedId = expanded ? '' : id),
                  style: TextButton.styleFrom(
                    foregroundColor: iconColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 17),
                  label: Text(
                    expanded ? 'إظهار أقل' : 'قراءة المزيد',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

            // زر "حدّث التطبيق" داخل الكارت (لو الرسالة ليها إصدار)
            if ((u['version'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final url = u['apk_url']?.toString() ??
                          UpdateChecker.instance.info?.apkUrl;
                      if (url != null) launchUpdateUrl(url);
                    },
                    icon: const Icon(Icons.system_update_alt_rounded, size: 18),
                    label: const Text('حدّث التطبيق'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),

            SizedBox(height: bodyText.isEmpty || !needsTruncate ? 14 : 16),
          ],
        ),
      ),
    );
  }

  Widget _ownerAction(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

}
