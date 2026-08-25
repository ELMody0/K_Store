import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import '../../../../core/utils/role_localization.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _totalUsers = 0;
  int _totalProducts = 0;
  int _totalCategories = 0;
  Map<String, int> _roleDistribution = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final usersResult = await _supabase.from('profiles').select('id, role');
      final productsResult = await _supabase.from('products').select('id');
      final categoriesResult = await _supabase.from('categories').select('id');

      final users = usersResult as List<dynamic>;
      final roles = <String, int>{};
      for (final user in users) {
        final role = user['role']?.toString().toLowerCase() ?? 'customer';
        roles[role] = (roles[role] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _totalUsers = users.length;
          _totalProducts = (productsResult as List).length;
          _totalCategories = (categoriesResult as List).length;
          _roleDistribution = roles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading statistics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('الإحصائيات', style: TextStyle(fontWeight: FontWeight.bold)),
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
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نظرة عامة', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 15,
                        runSpacing: 15,
                        children: [
                          SizedBox(width: (MediaQuery.of(context).size.width - 65) / 2, child: _buildStatCard(Icons.people_alt_rounded, 'المستخدمين', _totalUsers.toString(), textColor, isDark)),
                          SizedBox(width: (MediaQuery.of(context).size.width - 65) / 2, child: _buildStatCard(Icons.inventory_2_rounded, 'المنتجات', _totalProducts.toString(), textColor, isDark)),
                          SizedBox(width: (MediaQuery.of(context).size.width - 65) / 2, child: _buildStatCard(Icons.category_rounded, 'الأقسام', _totalCategories.toString(), textColor, isDark)),
                          SizedBox(width: (MediaQuery.of(context).size.width - 65) / 2, child: _buildStatCard(Icons.admin_panel_settings_rounded, 'المالكين', (_roleDistribution['owner'] ?? 0).toString(), textColor, isDark)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('توزيع الرتب', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      ..._roleDistribution.entries.map((entry) => FadeInLeft(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkGrey : Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: textColor.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(roleToArabic(entry.key), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: textColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text('${entry.value}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value, Color textColor, bool isDark) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkGrey : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}