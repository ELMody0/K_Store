import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'categories_management_page.dart';
import 'users_management_page.dart';
import 'products_management_page.dart';
import 'statistics_page.dart';
import 'support_chats_page.dart';
import 'reports_page.dart';

class _PanelItem {
  final IconData icon;
  final String title;
  final Color c1;
  final Color c2;
  final Widget page;
  const _PanelItem(this.icon, this.title, this.c1, this.c2, this.page);
}

class OwnerPanel extends StatefulWidget {
  const OwnerPanel({super.key});

  @override
  State<OwnerPanel> createState() => _OwnerPanelState();
}

class _OwnerPanelState extends State<OwnerPanel> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final data = await _supabase.from('profiles').select('role').eq('id', uid).maybeSingle();
      if (mounted) setState(() => _isOwner = data?['role']?.toString().toLowerCase() == 'owner');
    } catch (_) {
      if (mounted) setState(() => _isOwner = false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final surfaceColor = isDark ? AppColors.darkGrey : Colors.white;

    // حماية: لو لسه بيلوّد أو مش owner نمنع الوصول للوحة
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_isOwner) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: textColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: WavyBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 56, color: textColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 20),
                  Text('غير مصرّح بالدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                  const SizedBox(height: 8),
                  Text('هذه الصفحة مخصصة للمالك فقط.', style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5)), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final items = [
      _PanelItem(Icons.people_alt_rounded, 'المستخدمين', const Color(0xFF1DA1F2), const Color(0xFF6DD5FA), const UsersManagementPage()),
      _PanelItem(Icons.inventory_2_rounded, 'المنتجات', const Color(0xFFD4AF37), const Color(0xFFFFE08A), const ProductsManagementPage()),
      _PanelItem(Icons.category_rounded, 'الأقسام', const Color(0xFF9B59B6), const Color(0xFFE091E0), const CategoriesManagementPage()),
      _PanelItem(Icons.bar_chart_rounded, 'الإحصائيات', const Color(0xFF2ECC71), const Color(0xFFA8E6CF), const StatisticsPage()),
      _PanelItem(Icons.support_agent_rounded, 'الدعم', const Color(0xFFFF8C42), const Color(0xFFFFD3A3), const SupportChatsPage()),
      _PanelItem(Icons.flag_outlined, 'البلاغات', const Color(0xFFE74C3C), const Color(0xFFFFA8A0), const ReportsPage()),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('لوحة التحكم', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WavyBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 100),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 22,
            crossAxisSpacing: 22,
            children: items.map((it) => _adminCard(context, it, textColor, surfaceColor)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _adminCard(BuildContext context, _PanelItem item, Color textColor, Color surfaceColor) {
    return FadeInUp(
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: item.c1.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [item.c1, item.c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: item.c1.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: Icon(item.icon, size: 32, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Text(
                  item.title,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
