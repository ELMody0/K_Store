import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:k_store/features/auth/presentation/pages/auth_page.dart';
import 'package:k_store/core/services/update_checker.dart';
import 'package:k_store/core/services/app_update_service.dart';
import 'main_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // فحص التحديث التلقائي عند فتح التطبيق
    final update = await UpdateChecker.instance.check();

    if (!mounted) return;
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    // فحص الحظر: لو الحساب محظور نسجّله خروج ونودّي شاشة الدخول
    if (session?.user != null) {
      try {
        final profile = await supabase
            .from('profiles')
            .select('is_blocked')
            .eq('id', session!.user.id)
            .maybeSingle();
        if (profile != null && profile['is_blocked'] == true) {
          await supabase.auth.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تعطيل حسابك، تواصل مع الإدارة')),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthPage()),
            );
            return;
          }
        }
      } catch (_) {}
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              session != null ? const MainPage() : const AuthPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 1000),
        ),
      );

      // بعد ما نعدّي للشاشة الجديدة، لو فيه تحديث نعرض Dialog للمستخدم
      if (update?.isNewer == true) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _showUpdateDialog(update!);
        });
      }
    }
  }

  void _showUpdateDialog(SupabaseUpdateInfo update) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF16171A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'تحديث جديد متاح',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'الإصدار ${update.version} جاهز للتحميل',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
              textAlign: TextAlign.center,
            ),
            if (update.notes != null && update.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                update.notes!,
                style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white54 : Colors.black45, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('لاحقاً', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      UpdateChecker.instance.openUpdate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('تحديث الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ZoomIn(
                  duration: const Duration(milliseconds: 1200),
                  child: Container(
                    padding: const EdgeInsets.all(35),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                          blurRadius: 40,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: Icon(
                      Icons.shopping_bag_rounded,
                      size: 70,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: Text(
                    'K SHOP',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: Text(
                    'الفخامة في كل تفصيلة',
                    style: TextStyle(
                      fontSize: 16,
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                      letterSpacing: 2,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeIn(
              delay: const Duration(milliseconds: 1000),
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
