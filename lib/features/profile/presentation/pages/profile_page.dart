import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:k_store/core/theme/app_theme.dart';
import 'package:k_store/core/widgets/wavy_background.dart';
import 'package:k_store/features/auth/presentation/pages/auth_page.dart';
import 'edit_profile_page.dart';
import 'settings_page.dart';
import '../../../admin/presentation/pages/owner_panel.dart'; // المسار الصحيح
import '../../../../core/utils/role_localization.dart';
import 'package:k_store/core/widgets/app_image.dart';
import 'package:k_store/core/services/notification_service.dart';
import 'notification_settings_page.dart';
import 'support_panel_page.dart';
import 'about_us_page.dart';

const LinearGradient _neutralGradient = AppColors.neutralGradient;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userData;
  late final Stream<List<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();
    final uid = _supabase.auth.currentUser?.id;
    if (uid != null) {
      _profileStream = _supabase.from('profiles').stream(primaryKey: ['id']).eq('id', uid);
    }
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        if (mounted) {
          setState(() {
            _userData = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _openSupportChat(BuildContext context) async {
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SupportPanelPage()),
      );
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGrey,
        title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.auth.signOut();
      NotificationService().dispose();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final user = _supabase.auth.currentUser;

    if (user == null) return const AuthPage();

    return Scaffold(
      body: WavyBackground(
        child: SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            // استخدام Stream لمراقبة تغييرات ملف المستخدم لحظياً
            stream: _profileStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _userData == null) {
                return const Center(child: CircularProgressIndicator(color: Colors.white24));
              }

              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final data = snapshot.data!.first;
                // نحدّث الحالة بعد انتهاء الـ build (وليس أثناءه) لتجنّب تعديل الحالة جوه الـ build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _userData != data) setState(() => _userData = data);
                });
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildHeader(textColor, isDark),
                    const SizedBox(height: 40),
                    _buildProfileOptions(textColor, isDark),
                    const SizedBox(height: 120),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, bool isDark) {
    final avatarUrl = _userData?['avatar_url'];
    final name = _userData?['full_name'] ?? 'مستخدم K SHOP';
    final role = roleToArabic(_userData?['role']);

    return FadeInDown(
      child: Column(
        children: [
          // حلقة متدرجة محايدة حول الصورة الرمزية + ظل ناعم
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _neutralGradient,
              boxShadow: [
                BoxShadow(color: Colors.grey.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 8)),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.black : Colors.white),
              child: AppCircleAvatar(
                imageUrl: avatarUrl,
                radius: 58,
                backgroundColor: isDark ? AppColors.darkGrey : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (_userData?['is_verified'] == true) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified_rounded, color: Color(0xFF1DA1F2), size: 24),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // شارة الرتبة بلون محايد
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOptions(Color textColor, bool isDark) {
    final role = _userData?['role']?.toString().toLowerCase();
    final bool isOwner = role == 'owner';

    return FadeInUp(
      child: Column(
        children: [
          // عرض لوحة تحكم المالك فقط إذا كان المستخدم مالكاً
          if (isOwner)
            _buildOptionItem(
              icon: Icons.admin_panel_settings_rounded,
              label: 'لوحة تحكم المالك',
              textColor: textColor,
              isDark: isDark,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OwnerPanel()),
              ),
            ),
            
          _buildOptionItem(
            icon: Icons.edit_outlined,
            label: 'تعديل الملف الشخصي',
            textColor: textColor,
            isDark: isDark,
            onTap: () => Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (context) => EditProfilePage(
                  profileData: _userData,
                  onUpdate: () {}, // يتم التحديث الآن عبر الـ Stream تلقائياً
                ),
              ),
            ),
          ),
          _buildOptionItem(
            icon: Icons.settings_outlined,
            label: 'الإعدادات',
            textColor: textColor,
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
          ),
          _buildOptionItem(
            icon: Icons.notifications_outlined,
            label: 'الإشعارات',
            textColor: textColor,
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationSettingsPage())),
          ),
          _buildOptionItem(
            icon: Icons.support_agent_rounded,
            label: 'التواصل مع الإدارة',
            textColor: textColor,
            isDark: isDark,
            onTap: () => _openSupportChat(context),
          ),
          _buildOptionItem(
            icon: Icons.info_outline_rounded,
            label: 'من نحن',
            textColor: textColor,
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutUsPage())),
          ),
          const SizedBox(height: 20),
          _buildOptionItem(
            icon: Icons.logout_rounded,
            label: 'تسجيل الخروج',
            textColor: Colors.redAccent,
            isDark: isDark,
            onTap: _signOut,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required Color textColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkGrey : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: textColor, size: 22),
          ),
          title: Text(
            label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: textColor.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
